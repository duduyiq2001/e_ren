class AdminDeletionJob < ApplicationJob
  queue_as :default

  def perform(deletable_type, deletable_id, admin_user_id, reason = nil)
    admin_user = User.find(admin_user_id)
    deletable = deletable_type.constantize.find(deletable_id)
    
    # Perform soft delete with cascade
    deletable.soft_delete_with_cascade!(admin_user, reason: reason)
    
    # Log the deletion (in case it wasn't logged in controller)
    AdminAuditLog.create!(
      admin_user: admin_user,
      action: 'delete',
      target_type: deletable_type,
      target_id: deletable_id,
      metadata: { reason: reason, async: true },
      ip_address: nil, # Not available in background job
      user_agent: nil  # Not available in background job
    )
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "AdminDeletionJob failed: Record not found - #{e.message}"
  rescue StandardError => e
    Rails.logger.error "AdminDeletionJob failed: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise # Re-raise to trigger retry mechanism
  end
end

