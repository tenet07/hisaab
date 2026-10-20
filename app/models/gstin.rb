module Gstin
  FORMAT = /\A\d{2}[A-Z]{5}\d{4}[A-Z][1-9A-Z]Z[0-9A-Z]\z/
  CHARS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ".freeze

  module_function

  # Checks the 15th (checksum) character, so a mistyped GSTIN is caught at entry.
  def valid?(g)
    g = g.to_s.upcase
    return false unless g.match?(FORMAT)
    sum = g[0, 14].chars.each_with_index.sum do |c, i|
      v = CHARS.index(c) * (i.odd? ? 2 : 1)
      v / 36 + v % 36
    end
    CHARS[(36 - sum % 36) % 36] == g[14]
  end

  # Appends the check character to the first 14 characters (used for demo data and tests)
  def with_checksum(first14)
    sum = first14.chars.each_with_index.sum do |c, i|
      v = CHARS.index(c) * (i.odd? ? 2 : 1)
      v / 36 + v % 36
    end
    first14 + CHARS[(36 - sum % 36) % 36]
  end

  def state_code(g) = g.to_s[0, 2].presence
end
