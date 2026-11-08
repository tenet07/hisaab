class CreateDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :deliveries do |t|
      t.references :invoice, null: false, foreign_key: true, index: { unique: true }
      # pending -> loaded -> delivered | partly_delivered ; pending/loaded -> failed -> (rescheduled) pending
      t.string :status, null: false, default: "pending"
      t.date :run_date, null: false
      t.references :assigned_to, foreign_key: { to_table: :users }
      t.string :otp, null: false
      t.string :proof_kind # otp | photo
      t.binary :photo_data
      t.string :photo_type
      t.string :note
      t.datetime :loaded_at
      t.datetime :delivered_at
      t.integer :attempts, null: false, default: 0
      t.timestamps
    end
    add_index :deliveries, [:run_date, :status]

    create_table :delivery_items do |t|
      t.references :delivery, null: false, foreign_key: true
      t.references :invoice_line, null: false, foreign_key: true
      t.integer :loaded_qty
      t.integer :delivered_qty
      t.string :short_reason
      t.timestamps
    end

    create_table :credit_notes do |t|
      t.string :number, null: false
      t.date :date, null: false
      t.references :invoice, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.references :delivery, foreign_key: true
      t.string :reason, null: false
      t.integer :taxable_paise, null: false
      t.integer :cgst_paise, null: false
      t.integer :sgst_paise, null: false
      t.integer :igst_paise, null: false
      t.integer :total_paise, null: false
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end
    add_index :credit_notes, :number, unique: true

    add_reference :payments, :delivery, foreign_key: true
    add_reference :markets, :delivery_person, foreign_key: { to_table: :users }
  end
end
