module Admin
  class DebugController < AdminBaseController
    def deletion_test
      @users = User.all.limit(10)
      @test_user = User.find_by(email: 'user1@wustl.edu')
      @admin = User.find_by(email: 'admin@wustl.edu')
      
      render json: {
        admin: {
          id: @admin&.id,
          email: @admin&.email,
          role: @admin&.role,
          discarded: @admin&.discarded?
        },
        test_user: {
          id: @test_user&.id,
          email: @test_user&.email,
          role: @test_user&.role,
          discarded: @test_user&.discarded?,
          can_find_with_discarded: User.with_discarded.find(@test_user&.id).present? rescue false
        },
        all_users: @users.map { |u| { id: u.id, email: u.email, role: u.role, discarded: u.discarded? } },
        routes: {
          delete_user: admin_user_path(@test_user&.id),
          preview_user: deletion_preview_admin_user_path(@test_user&.id)
        }
      }
    end
  end
end

