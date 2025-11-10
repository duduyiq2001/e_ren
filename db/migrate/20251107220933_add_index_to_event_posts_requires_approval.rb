class AddIndexToEventPostsRequiresApproval < ActiveRecord::Migration[8.1]
  def change
    add_index :event_posts, :requires_approval
  end
end
