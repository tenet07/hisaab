class CreateSuppliers < ActiveRecord::Migration[8.1]
  def change
    create_table :suppliers do |t|
      t.string :name, null: false
      t.string :gstin
      t.string :state_code, null: false, default: "06"
      t.string :phone
      t.string :brands, null: false, default: "" # comma-separated brands bought from them
      t.integer :credit_days, null: false, default: 30
      t.timestamps
    end
    add_index :suppliers, :name, unique: true

    create_table :purchase_bills do |t|
      t.references :supplier, null: false, foreign_key: true
      t.string :number, null: false # the supplier's bill number
      t.date :date, null: false
      t.boolean :intra_state, null: false
      t.integer :taxable_paise, null: false
      t.integer :cgst_paise, null: false
      t.integer :sgst_paise, null: false
      t.integer :igst_paise, null: false
      t.integer :round_off_paise, null: false
      t.integer :total_paise, null: false
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end
    add_index :purchase_bills, [:supplier_id, :number], unique: true

    create_table :purchase_lines do |t|
      t.references :purchase_bill, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :qty, null: false
      t.integer :rate_paise, null: false
      t.integer :discount_paise, null: false, default: 0
      t.integer :gst_bp, null: false
      t.integer :taxable_paise, null: false
      t.integer :tax_paise, null: false
      t.timestamps
    end

    # Append-only. Payable = SUM(credit - debit) per supplier.
    create_table :supplier_entries do |t|
      t.references :supplier, null: false, foreign_key: true
      t.date :date, null: false
      t.string :kind, null: false # opening purchase payment_* claim_credit
      t.string :ref, null: false
      t.integer :debit_paise, null: false, default: 0
      t.integer :credit_paise, null: false, default: 0
      t.string :note
      t.references :user, null: false, foreign_key: true
      t.datetime :created_at, null: false
    end

    create_table :supplier_payments do |t|
      t.references :supplier, null: false, foreign_key: true
      t.date :date, null: false
      t.integer :amount_paise, null: false
      t.string :mode, null: false
      t.string :ref, null: false
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end

    create_table :claim_credits do |t|
      t.references :claim, null: false, foreign_key: true
      t.references :supplier, null: false, foreign_key: true
      t.string :number, null: false # the brand's credit note number
      t.date :date, null: false
      t.integer :amount_paise, null: false
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end
    add_reference :claims, :supplier, foreign_key: true
  end
end
