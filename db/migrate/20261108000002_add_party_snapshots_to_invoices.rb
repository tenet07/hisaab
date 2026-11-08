class AddPartySnapshotsToInvoices < ActiveRecord::Migration[8.1]
  # A tax invoice must reprint exactly as issued, even if the shop's or the
  # customer's details change later.
  def change
    add_column :invoices, :seller, :json
    add_column :invoices, :buyer, :json
  end
end
