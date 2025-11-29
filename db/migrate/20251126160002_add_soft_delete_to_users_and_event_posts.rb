class AddSoftDeleteToUsersAndEventPosts < ActiveRecord::Migration[8.1]
  def change
    # Add soft delete columns to users
    add_column :users, :deleted_at, :datetime
    add_column :users, :deleted_by_id, :bigint
    add_column :users, :deletion_reason, :text
    add_index :users, :deleted_at
    add_foreign_key :users, :users, column: :deleted_by_id

    # Add soft delete columns to event_posts
    add_column :event_posts, :deleted_at, :datetime
    add_column :event_posts, :deleted_by_id, :bigint
    add_column :event_posts, :deletion_reason, :text
    add_index :event_posts, :deleted_at
    add_foreign_key :event_posts, :users, column: :deleted_by_id
  end
end

