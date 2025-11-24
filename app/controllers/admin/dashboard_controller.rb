module Admin
  class DashboardController < AdminBaseController
    def index
      @users = User.order(created_at: :desc).limit(50)
      @event_posts = EventPost.order(created_at: :desc).limit(50)
      @deleted_users = User.discarded.order(deleted_at: :desc).limit(20)
      @deleted_events = EventPost.discarded.order(deleted_at: :desc).limit(20)
      @recent_audit_logs = AdminAuditLog.recent.limit(20)
    end
  end
end

