class User < ApplicationRecord
  # Devise modules
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable

  # Soft delete with discard (using deleted_at column)
  include Discard::Model
  self.discard_column = :deleted_at

  # Role enum
 enum :role, { student: 0, club_admin: 1, super_admin: 2 }, default: :student

  # Associations
  has_many :organized_events, class_name: 'EventPost', foreign_key: 'organizer_id', dependent: :destroy_async
  has_many :event_registrations, dependent: :destroy_async
  has_many :attended_events, through: :event_registrations, source: :event_post

  # Track who performed the deletion
  belongs_to :deleted_by_user, class_name: 'User', foreign_key: 'deleted_by_id', optional: true

  # Validations
  # Note: Devise handles email and password validations automatically, but email domain restriction is enforced below.
  validates :email, format: { with: /\A[\w+\-.]+@wustl\.edu\z/, message: "must be a wustl.edu email address" }
  validates :name, presence: true, length: { maximum: 100 }
  validates :phone_number, format: { with: /\A\+?[0-9\s\-\(\)]+\z/, allow_blank: true, message: "must be a valid phone number" }
  validates :e_score, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Scopes
  scope :by_e_score, -> { order(e_score: :desc) }
  scope :top_n, ->(n = 10) { by_e_score.limit(n) }

  # Admin methods
  def admin?
    super_admin?
  end

  def can_delete_user?(target_user)
    super_admin? && target_user.id != id # Can't delete self
  end

  def can_delete_event?(event_post)
    super_admin?
  end

  # Soft delete with cascading
  # Note: This method is designed to work in background jobs (AdminDeletionJob)
  # When called from a background job, the entire deletion process is async.
  # The destroy_async on associations (organized_events, event_registrations) means:
  # - When this user is destroyed, associated records will be deleted async via background jobs
  # - This ensures the deletion doesn't block the main thread
  def soft_delete_with_cascade!(admin_user, reason: nil)
    User.transaction do
      # Update deletion metadata first
      self.deleted_by_id = admin_user.id
      self.deletion_reason = reason
      save! # Save metadata before soft delete
      
      # Soft delete all user's events
      # Each event's destroy will trigger destroy_async on its registrations
      organized_events.each { |event| event.soft_delete_with_cascade!(admin_user, reason: "User deleted") }
      
      # Soft delete user's direct registrations
      # Since this method runs in a background job, these deletions are async
      event_registrations.each(&:destroy)
      
      # Perform soft delete on the user itself
      # This will trigger destroy_async on all dependent associations (organized_events, event_registrations)
      # The destroy_async dependency means associated records will be queued for async deletion
      discard
    end
  end

  # Get count of items that will be deleted
  def deletion_preview
    {
      organized_events: organized_events.count,
      event_registrations: event_registrations.count + organized_events.sum { |e| e.event_registrations.count },
      e_score: e_score
    }
  end

  # Methods
  def attending?(event_post)
    attended_events.include?(event_post)
  end

  def organizing?(event_post)
    organized_events.include?(event_post)
  end
end
