class AdminDeletionJob < ApplicationJob
  queue_as :default

  def perform(deletable_type, deletable_id, admin_user_id, reason = nil)
    admin_user = User.find(admin_user_id)
    deletable = deletable_type.constantize.find(deletable_id)
    
    # Perform hard delete with cascade
    deletable.soft_delete_with_cascade!(admin_user, reason: reason)
    
    # Note: Audit log is already created in the controller before queuing this job
    # We don't create another log here to avoid duplicates
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "AdminDeletionJob failed: Record not found - #{e.message}"
  rescue StandardError => e
    Rails.logger.error "AdminDeletionJob failed: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise # Re-raise to trigger retry mechanism
  end
end

