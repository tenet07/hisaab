# Turns a free-text order ("Philips 9W bulb 50 pc, 20W batten 10", Hinglish welcome) into draft
# order lines. Uses Claude when an API key is configured, and a catalog fuzzy-matcher otherwise
# (or if the call fails), so ordering never stops because the network did.
module OrderParser
  Line = Struct.new(:product, :quantity, :source_text, :confidence, keyword_init: true)
  module_function

  def draft!(customer:, text:, channel: "whatsapp", lines: nil)
    lines ||= parse(text)
    Order.create!(customer: customer, channel: channel, raw_message: text, status: "draft", created_by: Current.user,
                  lines_attributes: lines.map { |l| { product_id: l.product&.id, quantity: [l.quantity, 1].max,
                                                      source_text: l.source_text, confidence: l.confidence } })
  end

  def parse(text)
    return [] if text.blank?
    if Llm.enabled?
      begin
        lines = Llm.parse(text)
        return lines if lines.any?
      rescue StandardError => e
        Rails.logger.warn("[OrderParser] LLM parse failed, using fuzzy matcher: #{e.class}: #{e.message}")
      end
    end
    Fuzzy.parse(text)
  end

  # ── Claude ────────────────────────────────────────────────────────────────
  module Llm
    MODEL = "claude-opus-5-5"
    SCHEMA = {
      type: "object", additionalProperties: false, required: %w[lines],
      properties: {
        lines: { type: "array", items: {
          type: "object", additionalProperties: false, required: %w[product_id quantity source_text confidence],
          properties: {
            product_id: { anyOf: [{ type: "integer" }, { type: "null" }] },
            quantity: { type: "integer" },
            source_text: { type: "string" },
            confidence: { type: "number" }
          }
        } }
      }
    }.freeze

    module_function

    def api_key = ENV["ANTHROPIC_API_KEY"].presence || Rails.application.credentials.dig(:anthropic, :api_key)
    def enabled? = api_key.present?
    def client = @client ||= Anthropic::Client.new(api_key: api_key, timeout: 30, max_retries: 1)

    # The catalog goes in a cached system block (it changes rarely); only the message varies.
    def catalog_text
      Product.active.includes(:brand).order(:id).map do |p|
        "#{p.id} | #{p.brand.name} | #{p.name} | #{p.wattage} | sku #{p.sku} | also called: #{p.aliases}"
      end.join("\n")
    end

    def parse(text)
      products = Product.active.index_by(&:id)
      message = client.beta.messages.create(
        model: MODEL,
        max_tokens: 4000,
        betas: ["server-side-fallback-2026-07-01"],
        fallbacks: :default,
        output_config: { effort: "low", format_: { type: "json_schema", schema: SCHEMA } },
        system_: [
          { type: "text", text: <<~PROMPT },
            You read orders that retail shop owners send an electrical wholesaler on WhatsApp, often in Hinglish
            or Marathi-English shorthand ("bhai 9w philips 50 pc aur 20w batten 10 bhej do"). Split the message into
            one line per item and match each to a product id from the catalog. A brand mentioned once usually carries
            to the following items until another brand appears. "pc", "pcs", "nos", "piece" all mean pieces; a bare
            number next to an item is its quantity. If nothing in the catalog fits, use null for product_id.
            confidence is 0 to 1: how sure you are that the product and quantity are what the customer meant.
            source_text is the exact words of the message the line came from. Ignore greetings and delivery requests.
          PROMPT
          { type: "text", text: "Catalog (id | brand | name | wattage | sku | aliases):\n#{catalog_text}", cache_control: { type: "ephemeral" } }
        ],
        messages: [{ role: "user", content: text }]
      )
      raise "refused (#{message.stop_details&.category})" if message.stop_reason.to_s == "refusal"
      raise "truncated" if message.stop_reason.to_s == "max_tokens"
      json = message.content.find { _1.type.to_s == "text" }&.text
      data = JSON.parse(json.to_s)
      Array(data["lines"]).filter_map do |l|
        qty = l["quantity"].to_i
        next unless qty.positive?
        product = products[l["product_id"].to_i]
        Line.new(product: product, quantity: qty, source_text: l["source_text"].to_s.first(200),
                 confidence: product ? l["confidence"].to_f.clamp(0, 1).round(3) : 0)
      end
    end
  end

  # ── Fallback: token matching against names, wattages, brands and aliases ─────────
  module Fuzzy
    SPLIT = /[\n,;+]|\band\b|\baur\b|\bani\b|\bplus\b/i
    QTY = /(\d+)\s*(?:pcs?|pieces?|nos?|no\.|qty|box(?:es)?|pkts?)?\b/i
    DOZEN = /(\d+)\s*(?:dozen|dzn|darjan|dz)\b/i
    NOISE = %w[bhai bhej do dena please pls plz send kar ke chahiye hai sir ji order bhejo de ka ki ko and aur ani].freeze

    module_function

    def parse(text)
      products = Product.active.includes(:brand).to_a
      brands = Brand.all.to_a
      last_brand = nil
      text.split(SPLIT).filter_map do |chunk|
        chunk = chunk.strip
        next if chunk.blank?
        words = chunk.downcase.gsub(/[^a-z0-9\. ]/, " ").split
        brand = brands.find { |b| words.include?(b.name.downcase) }
        last_brand = brand if brand
        wattage = chunk[/(\d+(?:\.\d+)?)\s*w(?:att)?s?\b/i, 1]
        qty = quantity_in(chunk, wattage)
        next if qty.nil?
        product, score = best_match(products, words - NOISE - brands.map { _1.name.downcase }, wattage, brand || last_brand)
        Line.new(product: product, quantity: qty, source_text: chunk.first(200), confidence: product ? score : 0)
      end
    end

    def quantity_in(chunk, wattage)
      return chunk[DOZEN, 1].to_i * 12 if chunk.match?(DOZEN)
      nums = chunk.scan(QTY).flatten.map(&:to_i)
      nums.delete_at(nums.index(wattage.to_i)) if wattage && nums.index(wattage.to_i)
      nums.last
    end

    def best_match(products, words, wattage, brand)
      scored = products.map do |p|
        hay = [p.name, p.model, p.sku, p.aliases].compact.join(" ").downcase
        s = 0.0
        s += 0.45 if wattage && p.wattage.to_s.downcase == "#{wattage}w"
        s -= 0.4 if wattage && p.wattage.present? && p.wattage.to_s.downcase != "#{wattage}w"
        s += 0.25 if brand && p.brand_id == brand.id
        s -= 0.15 if brand && p.brand_id != brand.id
        hits = words.count { |w| w.length > 1 && w !~ /\A\d+w?\z/ && hay.include?(w) }
        s += [hits * 0.15, 0.35].min
        s += 0.2 if p.alias_list.any? { |a| words.join(" ").include?(a.downcase) }
        [p, s]
      end
      best = scored.max_by(&:last)
      return [nil, 0] if best.nil? || best.last < 0.35
      [best.first, best.last.clamp(0, 1).round(3)]
    end
  end
end
