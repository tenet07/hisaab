# Rupee helpers. Everything is stored and computed in integer paise; only display uses rupees.
module Money
  module_function

  def to_paise(rupees)
    return nil if rupees.nil? || rupees.to_s.strip.empty?
    (BigDecimal(rupees.to_s.delete(",₹ ")) * 100).round.to_i
  end

  # Indian digit grouping: ₹12,34,567.50
  def format(paise, symbol: true, decimals: true)
    paise = paise.to_i
    neg = paise.negative?
    rupees, p = paise.abs.divmod(100)
    s = rupees.to_s
    s = s.length > 3 ? "#{s[0..-4].reverse.scan(/\d{1,2}/).join(',').reverse},#{s[-3..]}" : s
    s += format_paise(p) if decimals
    "#{'-' if neg}#{'₹' if symbol}#{s}"
  end

  def format_paise(p) = ".#{p.to_s.rjust(2, '0')}"

  # ₹1.2L / ₹3.4Cr for dashboard tiles
  def compact(paise)
    r = paise.to_i / 100.0
    a = r.abs
    s = if a >= 1e7 then "#{(r / 1e7).round(2)}Cr"
        elsif a >= 1e5 then "#{(r / 1e5).round(2)}L"
        elsif a >= 1e3 then "#{(r / 1e3).round(1)}K"
        else r.round.to_s
        end
    "₹#{s.sub(/\.0+(?=\D|$)/, '')}"
  end

  # "One Thousand Two Hundred Rupees and Fifty Paise Only" — printed on GST invoices
  ONES = %w[Zero One Two Three Four Five Six Seven Eight Nine Ten Eleven Twelve Thirteen Fourteen Fifteen Sixteen
            Seventeen Eighteen Nineteen].freeze
  TENS = %w[_ _ Twenty Thirty Forty Fifty Sixty Seventy Eighty Ninety].freeze

  def in_words(paise)
    rupees, p = paise.to_i.abs.divmod(100)
    w = "#{words(rupees)} Rupees"
    w += " and #{words(p)} Paise" if p.positive?
    "#{w} Only"
  end

  def words(n)
    return ONES[n] if n < 20
    return [TENS[n / 10], (ONES[n % 10] if (n % 10).positive?)].compact.join(" ") if n < 100
    return [ONES[n / 100], "Hundred", (words(n % 100) if (n % 100).positive?)].compact.join(" ") if n < 1000
    [[10_000_000, "Crore"], [100_000, "Lakh"], [1000, "Thousand"]].each do |div, name|
      next if n < div
      return [words(n / div), name, (words(n % div) if (n % div).positive?)].compact.join(" ")
    end
  end
end
