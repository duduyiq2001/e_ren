class RemoveSoftDeleteColumns < ActiveRecord::Migration[8.1]
  def change
    # Remove soft delete columns from users
    remove_foreign_key :users, column: :deleted_by_id, if_exists: true
    remove_index :users, :deleted_at, if_exists: true
    remove_column :users, :deleted_at, :datetime, if_exists: true
    remove_column :users, :deleted_by_id, :bigint, if_exists: true
    remove_column :users, :deletion_reason, :text, if_exists: true

    # Remove soft delete columns from event_posts
    remove_foreign_key :event_posts, column: :deleted_by_id, if_exists: true
    remove_index :event_posts, :deleted_at, if_exists: true
    remove_column :event_posts, :deleted_at, :datetime, if_exists: true
    remove_column :event_posts, :deleted_by_id, :bigint, if_exists: true
    remove_column :event_posts, :deletion_reason, :text, if_exists: true

    # Remove soft delete columns from event_registrations
    remove_index :event_registrations, :deleted_at, if_exists: true
    remove_column :event_registrations, :deleted_at, :datetime, if_exists: true
  end
end
