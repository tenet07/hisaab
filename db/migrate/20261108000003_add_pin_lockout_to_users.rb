class AddPinLockoutToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :failed_pins, :integer, null: false, default: 0
    add_column :users, :locked_until, :datetime
  end
end
