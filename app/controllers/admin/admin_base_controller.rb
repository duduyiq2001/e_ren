module Admin
  class AdminBaseController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin

    private

    def require_admin
      unless current_user&.admin?
        render json: { error: 'Unauthorized. Admin access required.' }, status: :forbidden
      end
    end
  end
end

