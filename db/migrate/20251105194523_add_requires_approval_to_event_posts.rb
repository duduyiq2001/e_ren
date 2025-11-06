class AddRequiresApprovalToEventPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :event_posts, :requires_approval, :boolean, default: false, null: false
  end
end
