class CreateEventRegistrations < ActiveRecord::Migration[8.1]
  def change
    create_table :event_registrations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :event_post, null: false, foreign_key: true
      t.integer :status, default: 0, null: false
      t.datetime :registered_at, null: false

      t.timestamps
    end

    add_index :event_registrations, [:user_id, :event_post_id], unique: true, name: 'index_event_registrations_on_user_and_event'
  end
end
