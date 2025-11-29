class AddSoftDeleteToEventRegistrations < ActiveRecord::Migration[8.1]
  def change
    add_column :event_registrations, :deleted_at, :datetime
    add_index :event_registrations, :deleted_at
  end
end

