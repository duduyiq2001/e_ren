class AdminAuditLog < ApplicationRecord
  belongs_to :admin_user, class_name: 'User'

  validates :action, presence: true
  validates :target_type, presence: true
  validates :target_id, presence: true

  # Searchable by admin
  scope :recent, -> { order(created_at: :desc).limit(100) }
  scope :by_admin, ->(user_id) { where(admin_user_id: user_id) }
  scope :deletions, -> { where(action: 'delete') }
  scope :restorations, -> { where(action: 'restore') }
end

