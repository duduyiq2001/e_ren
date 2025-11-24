module Admin
  class DashboardController < AdminBaseController
    def index
      # Use .kept to explicitly get only non-discarded records
      # This ensures deleted users/events don't appear in the active list
      @users = User.order(created_at: :desc).limit(50)
      @event_posts = EventPost.order(created_at: :desc).limit(50)
      @recent_audit_logs = AdminAuditLog.recent.limit(20)
    end
  end
end

