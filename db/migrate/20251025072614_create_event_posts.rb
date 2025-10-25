class CreateEventPosts < ActiveRecord::Migration[8.1]
  def change
    create_table :event_posts do |t|
      t.string :name, null: false
      t.text :description
      t.references :event_category, null: false, foreign_key: true
      t.bigint :organizer_id, null: false
      t.integer :capacity, null: false
      t.datetime :event_time, null: false
      t.string :location_name
      t.string :google_maps_url
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6
      t.string :google_place_id
      t.text :formatted_address
      t.integer :registrations_count, default: 0, null: false

      t.timestamps
    end

    add_foreign_key :event_posts, :users, column: :organizer_id
    add_index :event_posts, :organizer_id
    add_index :event_posts, :event_time
    add_index :event_posts, [:latitude, :longitude]
    add_index :event_posts, [:event_category_id, :event_time]
  end
end
