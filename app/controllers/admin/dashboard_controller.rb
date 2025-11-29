module Admin
  class DashboardController < AdminBaseController
    def index
      @users = User.order(created_at: :desc).limit(50)
      @event_posts = EventPost.order(created_at: :desc).limit(50)
      @event_categories = EventCategory.order(:name).includes(:event_posts)
      @recent_audit_logs = AdminAuditLog.recent.limit(20)
    end
  end
end

