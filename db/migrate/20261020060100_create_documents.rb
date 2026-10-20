# Business documents. Each one, when posted, writes stock movements and/or ledger entries;
# the documents themselves never carry a stock count or a balance.
class CreateDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :orders do |t|
      t.string :number, null: false
      t.references :customer, null: false, foreign_key: true
      t.string :channel, null: false # whatsapp | salesman | counter
      t.string :status, null: false, default: "draft" # draft | confirmed | invoiced | cancelled
      t.text :raw_message
      t.text :notes
      t.references :created_by, foreign_key: { to_table: :users }
      t.string :client_uuid
      t.timestamps
    end
    add_index :orders, :number, unique: true
    add_index :orders, :client_uuid, unique: true

    create_table :order_lines do |t|
      t.references :order, null: false, foreign_key: true
      t.references :product, foreign_key: true
      t.integer :quantity, null: false
      t.bigint :rate_paise # nil = the customer's tier price
      t.decimal :discount_pct, precision: 5, scale: 2, null: false, default: 0
      t.string :source_text # the words this line was parsed from
      t.decimal :confidence, precision: 4, scale: 3
      t.timestamps
    end

    create_table :invoices do |t|
      t.string :number, null: false
      t.string :fy, null: false
      t.references :customer, null: false, foreign_key: true
      t.references :order, foreign_key: true
      t.date :invoice_date, null: false
      t.date :due_date, null: false
      t.string :status, null: false, default: "posted" # posted | cancelled
      t.string :channel, null: false, default: "counter"
      t.boolean :prices_include_tax, null: false, default: false
      # customer details as printed (the customer record may change later)
      t.string :bill_to_name, null: false
      t.string :bill_to_gstin
      t.string :place_of_supply, null: false
      t.text :bill_to_address
      t.bigint :taxable_paise, null: false, default: 0
      t.bigint :cgst_paise, null: false, default: 0
      t.bigint :sgst_paise, null: false, default: 0
      t.bigint :igst_paise, null: false, default: 0
      t.bigint :round_off_paise, null: false, default: 0
      t.bigint :total_paise, null: false, default: 0
      t.boolean :eway_required, null: false, default: false
      t.string :eway_bill_no
      t.string :irn
      t.references :posted_by, foreign_key: { to_table: :users }
      t.references :cancelled_by, foreign_key: { to_table: :users }
      t.datetime :cancelled_at
      t.string :cancel_reason
      t.timestamps
    end
    add_index :invoices, :number, unique: true

    create_table :invoice_lines do |t|
      t.references :invoice, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.string :description, null: false
      t.string :hsn, null: false
      t.integer :quantity, null: false
      t.bigint :rate_paise, null: false
      t.decimal :discount_pct, precision: 5, scale: 2, null: false, default: 0
      t.decimal :gst_rate, precision: 5, scale: 2, null: false
      t.bigint :taxable_paise, null: false
      t.bigint :cgst_paise, null: false, default: 0
      t.bigint :sgst_paise, null: false, default: 0
      t.bigint :igst_paise, null: false, default: 0
      t.bigint :total_paise, null: false
    end

    create_table :credit_notes do |t|
      t.string :number, null: false
      t.string :fy, null: false
      t.references :customer, null: false, foreign_key: true
      t.references :invoice, foreign_key: true
      t.date :note_date, null: false
      t.string :reason, null: false # return | shortfall | rate_difference | defective
      t.string :restock_bucket # where returned pieces go; nil = no stock movement
      t.bigint :taxable_paise, null: false, default: 0
      t.bigint :cgst_paise, null: false, default: 0
      t.bigint :sgst_paise, null: false, default: 0
      t.bigint :igst_paise, null: false, default: 0
      t.bigint :total_paise, null: false, default: 0
      t.references :created_by, foreign_key: { to_table: :users }
      t.text :notes
      t.timestamps
    end
    add_index :credit_notes, :number, unique: true

    create_table :credit_note_lines do |t|
      t.references :credit_note, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.references :invoice_line, foreign_key: true
      t.integer :quantity, null: false
      t.bigint :rate_paise, null: false
      t.decimal :gst_rate, precision: 5, scale: 2, null: false
      t.bigint :taxable_paise, null: false
      t.bigint :tax_paise, null: false
      t.bigint :total_paise, null: false
    end

    create_table :purchases do |t|
      t.references :supplier, null: false, foreign_key: true
      t.string :bill_no, null: false
      t.date :bill_date, null: false
      t.bigint :taxable_paise, null: false, default: 0
      t.bigint :tax_paise, null: false, default: 0
      t.bigint :total_paise, null: false, default: 0
      t.references :created_by, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :purchases, %i[supplier_id bill_no], unique: true

    create_table :purchase_lines do |t|
      t.references :purchase, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :quantity, null: false
      t.bigint :rate_paise, null: false
      t.decimal :gst_rate, precision: 5, scale: 2, null: false
      t.bigint :taxable_paise, null: false
      t.bigint :tax_paise, null: false
    end

    create_table :payments do |t|
      t.string :number, null: false
      t.references :customer, null: false, foreign_key: true
      t.bigint :amount_paise, null: false
      t.string :mode, null: false # cash | upi | cheque | bank
      t.string :reference # UTR / cheque number
      t.date :received_on, null: false
      t.string :status, null: false, default: "cleared" # cleared | bounced
      t.references :collected_by, foreign_key: { to_table: :users }
      t.string :client_uuid
      t.text :notes
      t.timestamps
    end
    add_index :payments, :number, unique: true
    add_index :payments, :client_uuid, unique: true
    add_check_constraint :payments, "amount_paise > 0", name: "payment_positive"

    create_table :payment_allocations do |t|
      t.references :payment, null: false, foreign_key: true
      t.references :invoice, null: false, foreign_key: true
      t.bigint :amount_paise, null: false
      t.datetime :created_at, null: false
    end

    create_table :supplier_payments do |t|
      t.references :supplier, null: false, foreign_key: true
      t.bigint :amount_paise, null: false
      t.string :mode, null: false
      t.string :reference
      t.date :paid_on, null: false
      t.references :created_by, foreign_key: { to_table: :users }
      t.timestamps
    end

    create_table :brand_claims do |t|
      t.string :number, null: false
      t.references :brand, null: false, foreign_key: true
      t.references :supplier, foreign_key: true
      t.string :status, null: false, default: "open" # open | sent | settled
      t.date :sent_on
      t.string :challan_no
      t.string :credit_note_ref
      t.date :settled_on
      t.bigint :credited_paise, null: false, default: 0
      t.references :created_by, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :brand_claims, :number, unique: true

    create_table :replacements do |t|
      t.string :number, null: false
      t.references :customer, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.references :invoice, foreign_key: true
      t.date :sold_on
      t.date :warranty_until
      t.boolean :warranty_valid, null: false, default: false
      t.string :outcome, null: false # swapped | charged | returned
      # where the defective piece is now
      t.string :claim_status, null: false, default: "awaiting" # awaiting | with_brand | credited | replaced | rejected | written_off | none
      t.references :brand_claim, foreign_key: true
      t.bigint :credited_paise, null: false, default: 0
      t.string :channel, null: false, default: "counter" # counter | route
      t.string :defect
      t.string :serial_no
      t.references :logged_by, foreign_key: { to_table: :users }
      t.string :client_uuid
      t.timestamps
    end
    add_index :replacements, :number, unique: true
    add_index :replacements, :client_uuid, unique: true

    create_table :approvals do |t|
      t.string :kind, null: false # write_off | discount
      t.references :subject, polymorphic: true, null: false
      t.string :status, null: false, default: "pending" # pending | approved | rejected
      t.text :reason
      t.bigint :amount_paise
      t.references :requested_by, foreign_key: { to_table: :users }
      t.references :decided_by, foreign_key: { to_table: :users }
      t.datetime :decided_at
      t.timestamps
    end

    create_table :dispatch_runs do |t|
      t.references :market, null: false, foreign_key: true
      t.date :run_date, null: false
      t.references :delivery_person, foreign_key: { to_table: :users }
      t.string :status, null: false, default: "planned" # planned | out | done
      t.string :vehicle
      t.timestamps
    end
    add_index :dispatch_runs, %i[market_id run_date], unique: true

    create_table :deliveries do |t|
      t.references :dispatch_run, null: false, foreign_key: true
      # an invoice goes out on one delivery
      t.references :invoice, null: false, foreign_key: true, index: { unique: true }
      t.integer :position, null: false, default: 0
      t.string :status, null: false, default: "pending" # pending | delivered | partial | failed
      t.string :otp_code
      t.boolean :otp_verified, null: false, default: false
      t.string :proof # photo | otp
      t.datetime :delivered_at
      t.references :delivered_by, foreign_key: { to_table: :users }
      t.text :notes
      t.string :client_uuid
      t.timestamps
    end

    create_table :stock_counts do |t|
      t.date :count_date, null: false
      t.string :status, null: false, default: "open" # open | posted
      t.references :counted_by, foreign_key: { to_table: :users }
      t.timestamps
    end
    create_table :stock_count_lines do |t|
      t.references :stock_count, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :system_qty, null: false
      t.integer :counted_qty
      t.string :reason
    end

    create_table :whatsapp_messages do |t|
      t.references :customer, foreign_key: true
      t.string :phone, null: false
      t.string :direction, null: false # out | in
      t.string :category, null: false # utility | marketing | service
      t.string :template
      t.text :body, null: false
      t.jsonb :payload, null: false, default: {}
      t.string :status, null: false, default: "queued" # queued | sent | delivered | read | failed | received
      t.string :provider_message_id
      t.integer :cost_paise, null: false, default: 0
      t.references :document, polymorphic: true
      t.string :error
      t.timestamps
    end

    create_table :broadcasts do |t|
      t.string :title, null: false
      t.text :body, null: false
      t.bigint :market_ids, array: true, null: false, default: []
      t.string :status, null: false, default: "draft" # draft | sent
      t.integer :recipients, null: false, default: 0
      t.references :created_by, foreign_key: { to_table: :users }
      t.datetime :sent_at
      t.timestamps
    end
  end
end
