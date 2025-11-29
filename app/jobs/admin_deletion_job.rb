class AdminDeletionJob < ApplicationJob
  queue_as :default

  def perform(deletable_type, deletable_id, admin_user_id, reason = nil)
    deletable = deletable_type.constantize.find(deletable_id)

    # Perform hard delete - dependent: :destroy on associations handles cascade
    deletable.destroy!

    # Note: Audit log is already created in the controller before queuing this job
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "AdminDeletionJob failed: Record not found - #{e.message}"
  rescue StandardError => e
    Rails.logger.error "AdminDeletionJob failed: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise # Re-raise to trigger retry mechanism
  end
end

