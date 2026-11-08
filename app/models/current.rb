# Per-request cache. Reset automatically between requests and tests.
class Current < ActiveSupport::CurrentAttributes
  attribute :settings
end
