class AdminDeletionJob < ApplicationJob
  queue_as :default

  def perform(deletable_type, deletable_id, admin_user_id, reason = nil)
    # Use with_discarded to find records even if they're already deleted
    # (though this shouldn't happen in normal flow)
    admin_user = User.with_discarded.find(admin_user_id)
    deletable = deletable_type.constantize.with_discarded.find(deletable_id)
    
    # Check if already deleted
    if deletable.discarded?
      Rails.logger.warn "AdminDeletionJob: Record #{deletable_type}##{deletable_id} is already deleted. Skipping."
      return
    end
    
    # Perform soft delete with cascade
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

