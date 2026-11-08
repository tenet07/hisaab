# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_08_000003) do
  create_table "claim_credits", force: :cascade do |t|
    t.integer "claim_id", null: false
    t.integer "supplier_id", null: false
    t.string "number", null: false
    t.date "date", null: false
    t.integer "amount_paise", null: false
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["claim_id"], name: "index_claim_credits_on_claim_id"
    t.index ["supplier_id"], name: "index_claim_credits_on_supplier_id"
    t.index ["user_id"], name: "index_claim_credits_on_user_id"
  end

  create_table "claim_lines", force: :cascade do |t|
    t.integer "claim_id", null: false
    t.integer "product_id", null: false
    t.integer "qty", null: false
    t.integer "settled_new_qty", default: 0, null: false
    t.integer "settled_credit_qty", default: 0, null: false
    t.integer "rejected_qty", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["claim_id"], name: "index_claim_lines_on_claim_id"
    t.index ["product_id"], name: "index_claim_lines_on_product_id"
  end

  create_table "claims", force: :cascade do |t|
    t.string "number", null: false
    t.string "brand", null: false
    t.date "sent_on", null: false
    t.string "status", default: "sent", null: false
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "supplier_id"
    t.index ["supplier_id"], name: "index_claims_on_supplier_id"
    t.index ["user_id"], name: "index_claims_on_user_id"
  end

  create_table "credit_notes", force: :cascade do |t|
    t.string "number", null: false
    t.date "date", null: false
    t.integer "invoice_id", null: false
    t.integer "customer_id", null: false
    t.integer "delivery_id"
    t.string "reason", null: false
    t.integer "taxable_paise", null: false
    t.integer "cgst_paise", null: false
    t.integer "sgst_paise", null: false
    t.integer "igst_paise", null: false
    t.integer "total_paise", null: false
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_credit_notes_on_customer_id"
    t.index ["delivery_id"], name: "index_credit_notes_on_delivery_id"
    t.index ["invoice_id"], name: "index_credit_notes_on_invoice_id"
    t.index ["number"], name: "index_credit_notes_on_number", unique: true
    t.index ["user_id"], name: "index_credit_notes_on_user_id"
  end

  create_table "customers", force: :cascade do |t|
    t.string "name", null: false
    t.string "owner_name"
    t.string "phone"
    t.string "gstin"
    t.string "state_code", default: "06", null: false
    t.string "price_tier", default: "wholesale", null: false
    t.integer "credit_limit_paise", default: 0, null: false
    t.integer "market_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "address"
    t.index ["market_id"], name: "index_customers_on_market_id"
    t.index ["phone"], name: "index_customers_on_phone"
  end

  create_table "deliveries", force: :cascade do |t|
    t.integer "invoice_id", null: false
    t.string "status", default: "pending", null: false
    t.date "run_date", null: false
    t.integer "assigned_to_id"
    t.string "otp", null: false
    t.string "proof_kind"
    t.binary "photo_data"
    t.string "photo_type"
    t.string "note"
    t.datetime "loaded_at"
    t.datetime "delivered_at"
    t.integer "attempts", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assigned_to_id"], name: "index_deliveries_on_assigned_to_id"
    t.index ["invoice_id"], name: "index_deliveries_on_invoice_id", unique: true
    t.index ["run_date", "status"], name: "index_deliveries_on_run_date_and_status"
  end

  create_table "delivery_items", force: :cascade do |t|
    t.integer "delivery_id", null: false
    t.integer "invoice_line_id", null: false
    t.integer "loaded_qty"
    t.integer "delivered_qty"
    t.string "short_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["delivery_id"], name: "index_delivery_items_on_delivery_id"
    t.index ["invoice_line_id"], name: "index_delivery_items_on_invoice_line_id"
  end

  create_table "invoice_lines", force: :cascade do |t|
    t.integer "invoice_id", null: false
    t.integer "product_id", null: false
    t.integer "qty", null: false
    t.integer "unit_price_paise", null: false
    t.integer "discount_paise", default: 0, null: false
    t.integer "gst_bp", null: false
    t.boolean "price_includes_tax", null: false
    t.integer "taxable_paise", null: false
    t.integer "tax_paise", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invoice_id"], name: "index_invoice_lines_on_invoice_id"
    t.index ["product_id"], name: "index_invoice_lines_on_product_id"
  end

  create_table "invoices", force: :cascade do |t|
    t.string "number", null: false
    t.date "date", null: false
    t.integer "customer_id", null: false
    t.boolean "intra_state", default: true, null: false
    t.integer "taxable_paise", null: false
    t.integer "cgst_paise", null: false
    t.integer "sgst_paise", null: false
    t.integer "igst_paise", null: false
    t.integer "round_off_paise", null: false
    t.integer "total_paise", null: false
    t.string "status", default: "posted", null: false
    t.string "channel", default: "counter", null: false
    t.integer "created_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "seller"
    t.json "buyer"
    t.index ["created_by_id"], name: "index_invoices_on_created_by_id"
    t.index ["customer_id"], name: "index_invoices_on_customer_id"
    t.index ["number"], name: "index_invoices_on_number", unique: true
  end

  create_table "ledger_entries", force: :cascade do |t|
    t.integer "customer_id", null: false
    t.date "date", null: false
    t.string "kind", null: false
    t.string "ref", null: false
    t.integer "debit_paise", default: 0, null: false
    t.integer "credit_paise", default: 0, null: false
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.index ["customer_id"], name: "index_ledger_entries_on_customer_id"
    t.index ["user_id"], name: "index_ledger_entries_on_user_id"
  end

  create_table "markets", force: :cascade do |t|
    t.string "name", null: false
    t.string "delivery_day"
    t.integer "salesman_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "delivery_person_id"
    t.index ["delivery_person_id"], name: "index_markets_on_delivery_person_id"
    t.index ["salesman_id"], name: "index_markets_on_salesman_id"
  end

  create_table "payments", force: :cascade do |t|
    t.integer "customer_id", null: false
    t.date "date", null: false
    t.integer "amount_paise", null: false
    t.string "mode", null: false
    t.string "ref", null: false
    t.string "note"
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "delivery_id"
    t.index ["customer_id"], name: "index_payments_on_customer_id"
    t.index ["delivery_id"], name: "index_payments_on_delivery_id"
    t.index ["user_id"], name: "index_payments_on_user_id"
  end

  create_table "products", force: :cascade do |t|
    t.string "sku", null: false
    t.string "name", null: false
    t.string "brand", null: false
    t.string "hsn", null: false
    t.integer "gst_bp", default: 1800, null: false
    t.integer "retail_price_paise", null: false
    t.integer "wholesale_price_paise", null: false
    t.boolean "price_includes_tax", default: false, null: false
    t.integer "warranty_months", default: 0, null: false
    t.integer "reorder_level", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sku"], name: "index_products_on_sku", unique: true
  end

  create_table "purchase_bills", force: :cascade do |t|
    t.integer "supplier_id", null: false
    t.string "number", null: false
    t.date "date", null: false
    t.boolean "intra_state", null: false
    t.integer "taxable_paise", null: false
    t.integer "cgst_paise", null: false
    t.integer "sgst_paise", null: false
    t.integer "igst_paise", null: false
    t.integer "round_off_paise", null: false
    t.integer "total_paise", null: false
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["supplier_id", "number"], name: "index_purchase_bills_on_supplier_id_and_number", unique: true
    t.index ["supplier_id"], name: "index_purchase_bills_on_supplier_id"
    t.index ["user_id"], name: "index_purchase_bills_on_user_id"
  end

  create_table "purchase_lines", force: :cascade do |t|
    t.integer "purchase_bill_id", null: false
    t.integer "product_id", null: false
    t.integer "qty", null: false
    t.integer "rate_paise", null: false
    t.integer "discount_paise", default: 0, null: false
    t.integer "gst_bp", null: false
    t.integer "taxable_paise", null: false
    t.integer "tax_paise", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_purchase_lines_on_product_id"
    t.index ["purchase_bill_id"], name: "index_purchase_lines_on_purchase_bill_id"
  end

  create_table "replacements", force: :cascade do |t|
    t.integer "customer_id", null: false
    t.integer "product_id", null: false
    t.integer "qty", default: 1, null: false
    t.string "invoice_number"
    t.date "sold_on"
    t.boolean "in_warranty", null: false
    t.string "note"
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_replacements_on_customer_id"
    t.index ["product_id"], name: "index_replacements_on_product_id"
    t.index ["user_id"], name: "index_replacements_on_user_id"
  end

  create_table "shop_settings", force: :cascade do |t|
    t.string "name", default: "My Shop", null: false
    t.text "address"
    t.string "phone"
    t.string "email"
    t.string "gstin"
    t.string "state_code", default: "06", null: false
    t.string "invoice_prefix", default: "INV", null: false
    t.string "credit_note_prefix", default: "CN", null: false
    t.string "bank_name"
    t.string "bank_account"
    t.string "bank_ifsc"
    t.string "upi_id"
    t.text "bill_terms"
    t.string "tally_company"
    t.json "tally_ledgers", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "stock_movements", force: :cascade do |t|
    t.integer "product_id", null: false
    t.string "bucket", null: false
    t.integer "qty", null: false
    t.string "reason", null: false
    t.string "ref"
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.index ["product_id", "bucket"], name: "index_stock_movements_on_product_id_and_bucket"
    t.index ["product_id"], name: "index_stock_movements_on_product_id"
    t.index ["user_id"], name: "index_stock_movements_on_user_id"
  end

  create_table "supplier_entries", force: :cascade do |t|
    t.integer "supplier_id", null: false
    t.date "date", null: false
    t.string "kind", null: false
    t.string "ref", null: false
    t.integer "debit_paise", default: 0, null: false
    t.integer "credit_paise", default: 0, null: false
    t.string "note"
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.index ["supplier_id"], name: "index_supplier_entries_on_supplier_id"
    t.index ["user_id"], name: "index_supplier_entries_on_user_id"
  end

  create_table "supplier_payments", force: :cascade do |t|
    t.integer "supplier_id", null: false
    t.date "date", null: false
    t.integer "amount_paise", null: false
    t.string "mode", null: false
    t.string "ref", null: false
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["supplier_id"], name: "index_supplier_payments_on_supplier_id"
    t.index ["user_id"], name: "index_supplier_payments_on_user_id"
  end

  create_table "suppliers", force: :cascade do |t|
    t.string "name", null: false
    t.string "gstin"
    t.string "state_code", default: "06", null: false
    t.string "phone"
    t.string "brands", default: "", null: false
    t.integer "credit_days", default: 30, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "address"
    t.index ["name"], name: "index_suppliers_on_name", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "role", null: false
    t.string "password_digest", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "failed_pins", default: 0, null: false
    t.datetime "locked_until"
    t.index ["name"], name: "index_users_on_name", unique: true
  end

  add_foreign_key "claim_credits", "claims"
  add_foreign_key "claim_credits", "suppliers"
  add_foreign_key "claim_credits", "users"
  add_foreign_key "claim_lines", "claims"
  add_foreign_key "claim_lines", "products"
  add_foreign_key "claims", "suppliers"
  add_foreign_key "claims", "users"
  add_foreign_key "credit_notes", "customers"
  add_foreign_key "credit_notes", "deliveries"
  add_foreign_key "credit_notes", "invoices"
  add_foreign_key "credit_notes", "users"
  add_foreign_key "customers", "markets"
  add_foreign_key "deliveries", "invoices"
  add_foreign_key "deliveries", "users", column: "assigned_to_id"
  add_foreign_key "delivery_items", "deliveries"
  add_foreign_key "delivery_items", "invoice_lines"
  add_foreign_key "invoice_lines", "invoices"
  add_foreign_key "invoice_lines", "products"
  add_foreign_key "invoices", "customers"
  add_foreign_key "invoices", "users", column: "created_by_id"
  add_foreign_key "ledger_entries", "customers"
  add_foreign_key "ledger_entries", "users"
  add_foreign_key "markets", "users", column: "delivery_person_id"
  add_foreign_key "markets", "users", column: "salesman_id"
  add_foreign_key "payments", "customers"
  add_foreign_key "payments", "deliveries"
  add_foreign_key "payments", "users"
  add_foreign_key "purchase_bills", "suppliers"
  add_foreign_key "purchase_bills", "users"
  add_foreign_key "purchase_lines", "products"
  add_foreign_key "purchase_lines", "purchase_bills"
  add_foreign_key "replacements", "customers"
  add_foreign_key "replacements", "products"
  add_foreign_key "replacements", "users"
  add_foreign_key "stock_movements", "products"
  add_foreign_key "stock_movements", "users"
  add_foreign_key "supplier_entries", "suppliers"
  add_foreign_key "supplier_entries", "users"
  add_foreign_key "supplier_payments", "suppliers"
  add_foreign_key "supplier_payments", "users"
end
