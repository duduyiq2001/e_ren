require 'rails_helper'

RSpec.describe 'Admin::Dashboard', type: :request do
  let(:admin) { create(:user, :admin, email: "admin-test-#{SecureRandom.hex(4)}@wustl.edu") }
  let(:student) { create(:user, email: "student-test-#{SecureRandom.hex(4)}@wustl.edu") }
  let!(:user1) { create(:user, email: "user1-test-#{SecureRandom.hex(4)}@wustl.edu") }
  let!(:user2) { create(:user, email: "user2-test-#{SecureRandom.hex(4)}@wustl.edu") }
  let!(:organizer1) { create(:user, email: "org1-test-#{SecureRandom.hex(4)}@wustl.edu") }
  let!(:organizer2) { create(:user, email: "org2-test-#{SecureRandom.hex(4)}@wustl.edu") }
  let!(:event1) { create(:event_post, organizer: organizer1) }
  let!(:event2) { create(:event_post, organizer: organizer2) }

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

