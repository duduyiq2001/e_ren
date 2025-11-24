require 'rails_helper'

RSpec.describe 'Admin::Dashboard', type: :request do
  let(:admin) { create(:user, :admin) }
  let(:student) { create(:user) }
  let!(:user1) { create(:user) }
  let!(:user2) { create(:user) }
  let!(:event1) { create(:event_post) }
  let!(:event2) { create(:event_post) }

  describe 'GET /admin' do
    context 'as admin' do
      before { sign_in admin }

      it 'returns success' do
        get admin_root_path
        expect(response).to have_http_status(:success)
      end

      it 'displays active users' do
        get admin_root_path
        expect(response.body).to include(user1.name)
        expect(response.body).to include(user2.name)
      end

      it 'displays active events' do
        get admin_root_path
        expect(response.body).to include(event1.name)
        expect(response.body).to include(event2.name)
      end

      it 'displays deleted items when they exist' do
        deleted_user = create(:user)
        deleted_user.discard
        
        get admin_root_path
        expect(response.body).to include('Deleted Items')
      end

      it 'displays audit log' do
        AdminAuditLog.create!(
          admin_user: admin,
          action: 'delete',
          target_type: 'User',
          target_id: user1.id
        )
        
        get admin_root_path
        expect(response.body).to include('Audit Log')
      end
    end

    context 'as non-admin' do
      before { sign_in student }

      it 'returns forbidden' do
        get admin_root_path
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when not signed in' do
      it 'redirects to login' do
        get admin_root_path
        expect(response).to have_http_status(:redirect)
      end
    end
  end
end

