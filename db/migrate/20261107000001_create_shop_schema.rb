class CreateShopSchema < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :role, null: false # owner accounts counter salesman delivery
      t.string :password_digest, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :users, :name, unique: true

    create_table :markets do |t|
      t.string :name, null: false
      t.string :delivery_day
      t.references :salesman, foreign_key: { to_table: :users }
      t.timestamps
    end

    create_table :customers do |t|
      t.string :name, null: false
      t.string :owner_name
      t.string :phone
      t.string :gstin
      t.string :state_code, null: false, default: "06" # Haryana
      t.string :price_tier, null: false, default: "wholesale"
      t.integer :credit_limit_paise, null: false, default: 0
      t.references :market, null: false, foreign_key: true
      t.timestamps
    end
    add_index :customers, :phone

    create_table :products do |t|
      t.string :sku, null: false
      t.string :name, null: false
      t.string :brand, null: false
      t.string :hsn, null: false
      t.integer :gst_bp, null: false, default: 1800
      t.integer :retail_price_paise, null: false
      t.integer :wholesale_price_paise, null: false
      t.boolean :price_includes_tax, null: false, default: false
      t.integer :warranty_months, null: false, default: 0
      t.integer :reorder_level, null: false, default: 0
      t.timestamps
    end
    add_index :products, :sku, unique: true

    create_table :invoices do |t|
      t.string :number, null: false
      t.date :date, null: false
      t.references :customer, null: false, foreign_key: true
      t.boolean :intra_state, null: false, default: true
      t.integer :taxable_paise, null: false
      t.integer :cgst_paise, null: false
      t.integer :sgst_paise, null: false
      t.integer :igst_paise, null: false
      t.integer :round_off_paise, null: false
      t.integer :total_paise, null: false
      t.string :status, null: false, default: "posted"
      t.string :channel, null: false, default: "counter"
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :invoices, :number, unique: true

    create_table :invoice_lines do |t|
      t.references :invoice, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :qty, null: false
      t.integer :unit_price_paise, null: false
      t.integer :discount_paise, null: false, default: 0
      t.integer :gst_bp, null: false
      t.boolean :price_includes_tax, null: false
      t.integer :taxable_paise, null: false
      t.integer :tax_paise, null: false
      t.timestamps
    end

    # Append-only. Stock = SUM(qty) per product + bucket.
    create_table :stock_movements do |t|
      t.references :product, null: false, foreign_key: true
      t.string :bucket, null: false
      t.integer :qty, null: false
      t.string :reason, null: false
      t.string :ref
      t.references :user, null: false, foreign_key: true
      t.datetime :created_at, null: false
    end
    add_index :stock_movements, [:product_id, :bucket]

    # Append-only. Balance = SUM(debit - credit) per customer.
    create_table :ledger_entries do |t|
      t.references :customer, null: false, foreign_key: true
      t.date :date, null: false
      t.string :kind, null: false
      t.string :ref, null: false
      t.integer :debit_paise, null: false, default: 0
      t.integer :credit_paise, null: false, default: 0
      t.references :user, null: false, foreign_key: true
      t.datetime :created_at, null: false
    end

    create_table :payments do |t|
      t.references :customer, null: false, foreign_key: true
      t.date :date, null: false
      t.integer :amount_paise, null: false
      t.string :mode, null: false
      t.string :ref, null: false
      t.string :note
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end

    create_table :claims do |t|
      t.string :number, null: false
      t.string :brand, null: false
      t.date :sent_on, null: false
      t.string :status, null: false, default: "sent"
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end

    create_table :claim_lines do |t|
      t.references :claim, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :qty, null: false
      t.integer :settled_new_qty, null: false, default: 0
      t.integer :settled_credit_qty, null: false, default: 0
      t.integer :rejected_qty, null: false, default: 0
      t.timestamps
    end

    create_table :replacements do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :qty, null: false, default: 1
      t.string :invoice_number
      t.date :sold_on
      t.boolean :in_warranty, null: false
      t.string :note
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end
  end
end
