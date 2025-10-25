class CreateEventCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :event_categories do |t|
      t.string :name
      t.string :icon
      t.string :color

      t.timestamps
    end
  end
end
