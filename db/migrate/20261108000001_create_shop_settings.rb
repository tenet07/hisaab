class CreateShopSettings < ActiveRecord::Migration[8.1]
  def change
    # One row per database. When the app serves several wholesalers (one
    # database each), every shop carries its own settings here.
    create_table :shop_settings do |t|
      t.string :name, null: false, default: "My Shop"
      t.text :address
      t.string :phone
      t.string :email
      t.string :gstin
      t.string :state_code, null: false, default: "06"
      t.string :invoice_prefix, null: false, default: "INV"
      t.string :credit_note_prefix, null: false, default: "CN"
      t.string :bank_name
      t.string :bank_account
      t.string :bank_ifsc
      t.string :upi_id
      t.text :bill_terms
      t.string :tally_company
      t.json :tally_ledgers, null: false, default: {}
      t.timestamps
    end
    add_column :customers, :address, :text
    add_column :suppliers, :address, :text
  end
end
