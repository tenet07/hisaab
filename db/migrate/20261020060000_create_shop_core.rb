# The shop's masters and its two ledgers. Money is integer paise; quantities are whole pieces.
# Stock and balances are never stored: they are sums of stock_movements and ledger_entries,
# which the database itself refuses to update or delete.
class CreateShopCore < ActiveRecord::Migration[8.0]
  def change
    change_table :users do |t|
      t.string :name, null: false, default: ""
      t.string :role, null: false, default: "counter"
      t.string :phone
      t.boolean :active, null: false, default: true
    end

    change_table :sessions do |t|
      t.string :device_label
    end

    create_table :shop_settings do |t|
      t.string :name, null: false, default: "My Electricals"
      t.string :legal_name
      t.string :gstin
      t.string :state_code, null: false, default: "27" # Maharashtra; set to the shop's state
      t.text :address
      t.string :phone
      t.string :email
      t.string :upi_id
      t.string :invoice_prefix, null: false, default: "INV"
      t.integer :credit_days, null: false, default: 30
      t.bigint :eway_threshold_paise, null: false, default: 5_000_000
      t.boolean :einvoice_enabled, null: false, default: false
      t.integer :claim_flag_days, null: false, default: 45
      t.decimal :discount_approval_pct, precision: 5, scale: 2, null: false, default: 10
      t.bigint :writeoff_approval_paise, null: false, default: 0
      t.string :whatsapp_provider, null: false, default: "log"
      t.text :bank_details
      t.timestamps
    end

    create_table :markets do |t|
      t.string :name, null: false
      t.integer :delivery_weekday # 0 = Sunday
      t.references :salesman, foreign_key: { to_table: :users }
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :markets, :name, unique: true

    create_table :brands do |t|
      t.string :name, null: false
      t.integer :warranty_months, null: false, default: 12
      t.string :claim_contact
      t.timestamps
    end
    add_index :brands, :name, unique: true

    create_table :products do |t|
      t.references :brand, null: false, foreign_key: true
      t.string :sku, null: false
      t.string :name, null: false
      t.string :model
      t.string :wattage
      t.string :hsn, null: false
      t.decimal :gst_rate, precision: 5, scale: 2, null: false, default: 18
      t.bigint :mrp_paise, null: false, default: 0
      t.bigint :retail_paise, null: false, default: 0
      t.bigint :wholesale_paise, null: false, default: 0
      t.bigint :purchase_paise, null: false, default: 0
      t.integer :reorder_level, null: false, default: 0
      t.integer :warranty_months # nil = brand default
      t.string :unit, null: false, default: "pc"
      t.text :aliases # words customers use for it in WhatsApp orders
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :products, :sku, unique: true

    create_table :customers do |t|
      t.string :code, null: false
      t.string :shop_name, null: false
      t.string :owner_name
      t.string :phone, null: false
      t.string :gstin
      t.string :state_code
      t.text :address
      t.references :market, foreign_key: true
      t.bigint :credit_limit_paise, null: false, default: 0
      t.string :price_tier, null: false, default: "wholesale"
      t.boolean :marketing_opt_in, null: false, default: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :customers, :code, unique: true
    add_index :customers, :phone

    create_table :suppliers do |t|
      t.string :name, null: false
      t.references :brand, foreign_key: true
      t.string :gstin
      t.string :state_code
      t.string :phone
      t.text :address
      t.timestamps
    end

    # Per financial-year serials for every numbered document (GST requires one series per FY)
    create_table :document_sequences do |t|
      t.string :kind, null: false
      t.string :fy, null: false
      t.integer :last_number, null: false, default: 0
    end
    add_index :document_sequences, %i[kind fy], unique: true

    # ── the two ledgers ────────────────────────────────────────────────
    create_table :stock_movements do |t|
      t.references :product, null: false, foreign_key: true
      t.string :bucket, null: false # sellable | awaiting_claim | with_brand | written_off
      t.integer :quantity, null: false # signed: + in, - out
      t.string :reason, null: false
      t.references :document, polymorphic: true
      t.references :user, foreign_key: true
      t.string :device
      t.text :note
      t.datetime :created_at, null: false
    end
    add_index :stock_movements, %i[product_id bucket]
    add_check_constraint :stock_movements, "quantity <> 0", name: "stock_movement_nonzero"
    add_check_constraint :stock_movements, "bucket IN ('sellable','awaiting_claim','with_brand','written_off')", name: "stock_movement_bucket"

    create_table :ledger_entries do |t|
      t.references :party, polymorphic: true, null: false # Customer or Supplier
      t.date :entry_date, null: false
      t.bigint :debit_paise, null: false, default: 0
      t.bigint :credit_paise, null: false, default: 0
      t.string :entry_type, null: false
      t.references :document, polymorphic: true
      t.string :narration
      t.references :user, foreign_key: true
      t.string :device
      t.datetime :created_at, null: false
    end
    add_index :ledger_entries, %i[party_type party_id entry_date]
    add_check_constraint :ledger_entries, "debit_paise >= 0 AND credit_paise >= 0 AND (debit_paise > 0) <> (credit_paise > 0)", name: "ledger_one_side"

    reversible do |dir|
      dir.up do
        execute <<~SQL
          CREATE FUNCTION forbid_ledger_change() RETURNS trigger AS $$
          BEGIN
            RAISE EXCEPTION '% is append-only: post a reversing entry instead of %', TG_TABLE_NAME, TG_OP;
          END $$ LANGUAGE plpgsql;
          CREATE TRIGGER stock_movements_append_only BEFORE UPDATE OR DELETE ON stock_movements
            FOR EACH ROW EXECUTE FUNCTION forbid_ledger_change();
          CREATE TRIGGER ledger_entries_append_only BEFORE UPDATE OR DELETE ON ledger_entries
            FOR EACH ROW EXECUTE FUNCTION forbid_ledger_change();
        SQL
      end
      dir.down do
        execute "DROP TRIGGER stock_movements_append_only ON stock_movements; DROP TRIGGER ledger_entries_append_only ON ledger_entries; DROP FUNCTION forbid_ledger_change();"
      end
    end

    # who changed which master record, and how
    create_table :audit_events do |t|
      t.references :user, foreign_key: true
      t.references :subject, polymorphic: true
      t.string :action, null: false
      t.jsonb :changeset, null: false, default: {}
      t.string :device
      t.datetime :created_at, null: false
    end
  end
end
