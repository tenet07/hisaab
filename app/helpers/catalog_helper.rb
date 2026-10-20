module CatalogHelper
  # Products as JSON for the type-to-search picker, with stock and every price tier.
  def product_catalog_json
    stock = StockMovement.where(bucket: "sellable").group(:product_id).sum(:quantity)
    Product.active.includes(:brand).order(:brand_id, :name).map do |p|
      { id: p.id, label: p.display_name, meta: "#{p.sku} · #{stock[p.id].to_i} #{p.unit}", sku: p.sku, gst: p.gst_rate.to_f,
        stock: stock[p.id].to_i, unit: p.unit, **(can?(:margins) || can?(:purchases) ? { purchase: p.purchase_paise } : {}), warranty: p.effective_warranty_months,
        prices: { "wholesale" => p.price_paise_for(nil), "retail" => p.price_paise_for(Customer.new(price_tier: "retail")), "mrp" => p.mrp_paise },
        search: [p.display_name, p.sku, p.model, p.wattage, p.aliases].compact.join(" ").downcase }
    end.to_json
  end

  def customer_catalog_json
    Customer.active.includes(:market).order(:shop_name).map do |c|
      { id: c.id, label: c.shop_name, meta: [c.code, c.market&.name].compact.join(" · "), tier: c.price_tier, b2b: c.gstin.present?, incl: c.prices_include_tax?,
        search: [c.shop_name, c.owner_name, c.code, c.phone, c.market&.name].compact.join(" ").downcase }
    end.to_json
  end

  def catalog_script(id, json) = tag.script(json.html_safe, type: "application/json", id: id)

  def combobox(name:, value: nil, label: nil, source:, placeholder: "Type to search…", autofocus: false, extra_action: nil, input_class: "input")
    tag.div(class: "relative", data: { controller: "combobox", combobox_source_value: source, combobox_autofocus_value: autofocus,
                                       action: extra_action }) do
      safe_join([
        hidden_field_tag(name, value, data: { combobox_target: "hidden" }, id: nil),
        text_field_tag(nil, label, placeholder: placeholder, class: input_class, id: nil,
                       data: { combobox_target: "input", action: "input->combobox#filter keydown->combobox#key blur->combobox#blur focus->combobox#filter" }),
        tag.ul(hidden: true, class: "absolute z-30 mt-1 max-h-72 w-full min-w-72 overflow-y-auto rounded-xl border border-slate-200 bg-white py-1 shadow-xl",
                             data: { combobox_target: "list" })
      ])
    end
  end
end
