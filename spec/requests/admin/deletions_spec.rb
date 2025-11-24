require 'rails_helper'

RSpec.describe 'Admin::Deletions', type: :request do
  let(:admin) { create(:user, :admin) }
  let(:student) { create(:user) }
  let(:target_user) { create(:user) }
  let(:event_post) { create(:event_post) }

  describe 'GET /admin/users/:id/deletion_preview' do
    context 'as admin' do
      before { sign_in admin }

      it 'returns deletion preview for user' do
        create_list(:event_post, 2, organizer: target_user)
        create_list(:event_registration, 3, user: target_user)

        get deletion_preview_admin_user_path(target_user)

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['type']).to eq('User')
        expect(json['id']).to eq(target_user.id)
        expect(json['will_delete']).to be_present
      end
    end

    context 'as non-admin' do
      before { sign_in student }

      it 'returns forbidden' do
        get deletion_preview_admin_user_path(target_user)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when not signed in' do
      it 'redirects to login' do
        get deletion_preview_admin_user_path(target_user)
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'GET /admin/event_posts/:id/deletion_preview' do
    context 'as admin' do
      before { sign_in admin }

      it 'returns deletion preview for event' do
        create_list(:event_registration, 3, event_post: event_post)

        get deletion_preview_admin_event_post_path(event_post)

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['type']).to eq('EventPost')
        expect(json['id']).to eq(event_post.id)
        expect(json['will_delete']).to be_present
      end
    end
  end

  describe 'DELETE /admin/users/:id' do
    context 'as admin' do
      before { sign_in admin }

      it 'requires DELETE confirmation' do
        delete admin_user_path(target_user), params: { confirmation: 'wrong' }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(target_user.reload.discarded?).to be false
      end

      it 'soft deletes with valid confirmation' do
        delete admin_user_path(target_user), params: {
          confirmation: 'DELETE',
          reason: 'Test deletion'
        }

        expect(response).to have_http_status(:success)
        expect(target_user.reload.discarded?).to be true
        json = JSON.parse(response.body)
        expect(json['success']).to be true
      end

      it 'creates audit log entry' do
        expect {
          delete admin_user_path(target_user), params: { confirmation: 'DELETE' }
        }.to change(AdminAuditLog, :count).by(1)

        log = AdminAuditLog.last
        expect(log.action).to eq('delete')
        expect(log.admin_user).to eq(admin)
        expect(log.target_type).to eq('User')
        expect(log.target_id).to eq(target_user.id)
      end

      it 'prevents admin from deleting themselves' do
        delete admin_user_path(admin), params: { confirmation: 'DELETE' }
        expect(response).to have_http_status(:forbidden)
        expect(admin.reload.discarded?).to be false
      end

      it 'cascades deletion to user events' do
        event = create(:event_post, organizer: target_user)
        delete admin_user_path(target_user), params: { confirmation: 'DELETE' }

        expect(target_user.reload.discarded?).to be true
        expect(event.reload.discarded?).to be true
      end
    end

    context 'as non-admin' do
      before { sign_in student }

      it 'returns forbidden' do
        delete admin_user_path(target_user), params: { confirmation: 'DELETE' }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'DELETE /admin/event_posts/:id' do
    context 'as admin' do
      before { sign_in admin }

      it 'soft deletes event with valid confirmation' do
        delete admin_event_post_path(event_post), params: {
          confirmation: 'DELETE',
          reason: 'Inappropriate content'
        }

        expect(response).to have_http_status(:success)
        expect(event_post.reload.discarded?).to be true
      end

      it 'cascades deletion to registrations' do
        registration = create(:event_registration, event_post: event_post)
        delete admin_event_post_path(event_post), params: { confirmation: 'DELETE' }

        expect(event_post.reload.discarded?).to be true
        expect(registration.reload.discarded?).to be true
      end
    end
  end

  describe 'POST /admin/restore/:type/:id' do
    let(:deleted_user) { create(:user).tap { |u| u.update_column(:deleted_at, 1.day.ago) } }
    let(:deleted_event) { create(:event_post).tap { |e| e.update_column(:deleted_at, 1.day.ago) } }

    context 'as admin' do
      before { sign_in admin }

      it 'restores soft-deleted user' do
        post admin_restore_path(type: 'user', id: deleted_user.id)

        expect(response).to have_http_status(:success)
        expect(deleted_user.reload.discarded?).to be false
      end

      it 'restores soft-deleted event' do
        post admin_restore_path(type: 'event_post', id: deleted_event.id)

        expect(response).to have_http_status(:success)
        expect(deleted_event.reload.discarded?).to be false
      end

      it 'creates audit log for restoration' do
        expect {
          post admin_restore_path(type: 'user', id: deleted_user.id)
        }.to change(AdminAuditLog, :count).by(1)

        log = AdminAuditLog.last
        expect(log.action).to eq('restore')
        expect(log.target_type).to eq('User')
      end
    end

    context 'as non-admin' do
      before { sign_in student }

      it 'returns forbidden' do
        post admin_restore_path(type: 'user', id: deleted_user.id)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end

