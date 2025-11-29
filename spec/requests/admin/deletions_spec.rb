require 'rails_helper'

RSpec.describe 'Admin::Deletions', type: :request do
  include ActiveJob::TestHelper

  let(:admin) { create(:user, :admin, email: "admin-del-test-#{SecureRandom.hex(4)}@wustl.edu") }
  let(:student) { create(:user, email: "student-del-test-#{SecureRandom.hex(4)}@wustl.edu") }
  let(:target_user) { create(:user, email: "target-del-test-#{SecureRandom.hex(4)}@wustl.edu") }
  let(:event_organizer) { create(:user, email: "org-del-test-#{SecureRandom.hex(4)}@wustl.edu") }
  let(:event_post) { create(:event_post, organizer: event_organizer) }

  before do
    ActiveJob::Base.queue_adapter = :test
  end

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
        # User should still exist (not deleted)
        expect(User.find(target_user.id)).to be_present
      end

      it 'hard deletes with valid confirmation' do
        user_id = target_user.id
        delete admin_user_path(target_user), params: {
          confirmation: 'DELETE',
          reason: 'Test deletion'
        }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['success']).to be true
        
        # Execute the enqueued job to perform the actual deletion
        perform_enqueued_jobs
        
        # Record should be hard deleted (not found)
        expect { User.find(user_id) }.to raise_error(ActiveRecord::RecordNotFound)
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
        admin_id = admin.id
        delete admin_user_path(admin), params: { confirmation: 'DELETE' }
        expect(response).to have_http_status(:forbidden)
        # Admin should still exist (not deleted)
        expect(User.find(admin_id)).to be_present
      end

      it 'cascades deletion to user events' do
        event = create(:event_post, organizer: target_user)
        user_id = target_user.id
        event_id = event.id
        delete admin_user_path(target_user), params: { confirmation: 'DELETE' }

        # Execute the enqueued job to perform the actual deletion
        perform_enqueued_jobs

        # Records should be hard deleted (not found)
        expect { User.find(user_id) }.to raise_error(ActiveRecord::RecordNotFound)
        expect { EventPost.find(event_id) }.to raise_error(ActiveRecord::RecordNotFound)
      end

      context 'when user has registrations in events' do
        let!(:organizer1) { create(:user, email: "org1-req-#{SecureRandom.hex(4)}@wustl.edu") }
        let!(:organizer2) { create(:user, email: "org2-req-#{SecureRandom.hex(4)}@wustl.edu") }
        let!(:organizer3) { create(:user, email: "org3-req-#{SecureRandom.hex(4)}@wustl.edu") }
        let!(:organizer4) { create(:user, email: "org4-req-#{SecureRandom.hex(4)}@wustl.edu") }
        let!(:organizer5) { create(:user, email: "org5-req-#{SecureRandom.hex(4)}@wustl.edu") }
        
        let!(:event1) { create(:event_post, organizer: organizer1) }
        let!(:event2) { create(:event_post, organizer: organizer2) }
        let!(:event3) { create(:event_post, organizer: organizer3) }
        let!(:event4) { create(:event_post, organizer: organizer4, requires_approval: true) }
        let!(:event5) { create(:event_post, organizer: organizer5, requires_approval: true) }
        
        let!(:confirmed_reg1) { create(:event_registration, user: target_user, event_post: event1, status: :confirmed) }
        let!(:confirmed_reg2) { create(:event_registration, user: target_user, event_post: event2, status: :confirmed) }
        let!(:waitlisted_reg) { create(:event_registration, user: target_user, event_post: event3, status: :waitlisted) }
        let!(:pending_reg) { create(:event_registration, user: target_user, event_post: event4, status: :pending) }
        
        # Add other users' registrations to establish baseline counts
        let!(:other_user1) { create(:user, email: "other1-req-#{SecureRandom.hex(4)}@wustl.edu") }
        let!(:other_user2) { create(:user, email: "other2-req-#{SecureRandom.hex(4)}@wustl.edu") }
        let!(:other_confirmed1) { create(:event_registration, user: other_user1, event_post: event1, status: :confirmed) }
        let!(:other_confirmed2) { create(:event_registration, user: other_user2, event_post: event2, status: :confirmed) }
        
        before do
          # Reload events to get accurate counts
          event1.reload
          event2.reload
          event3.reload
          event4.reload
          event5.reload
        end

        it 'decrements registrations_count for events with confirmed registrations' do
          initial_count1 = event1.registrations_count
          initial_count2 = event2.registrations_count
          initial_count3 = event3.registrations_count
          initial_count4 = event4.registrations_count

          delete admin_user_path(target_user), params: { confirmation: 'DELETE' }
          perform_enqueued_jobs

          # Reload events (they should still exist, only registrations are deleted)
          event1.reload
          event2.reload
          event3.reload
          event4.reload

          # Event1: should decrease by 1 (confirmed_reg1 was hard deleted)
          expect(event1.registrations_count).to eq(initial_count1 - 1)

          # Event2: should decrease by 1 (confirmed_reg2 was hard deleted)
          expect(event2.registrations_count).to eq(initial_count2 - 1)

          # Event3: should not change (waitlisted_reg doesn't affect count)
          expect(event3.registrations_count).to eq(initial_count3)

          # Event4: should not change (pending_reg doesn't affect count)
          expect(event4.registrations_count).to eq(initial_count4)
        end

        it 'only affects confirmed registrations, not waitlisted or pending' do
          initial_count3 = event3.registrations_count
          initial_count4 = event4.registrations_count

          delete admin_user_path(target_user), params: { confirmation: 'DELETE' }
          perform_enqueued_jobs

          event3.reload
          event4.reload

          # Counts should not change for waitlisted/pending registrations
          expect(event3.registrations_count).to eq(initial_count3)
          expect(event4.registrations_count).to eq(initial_count4)
        end

        it 'maintains correct counts for other users registrations' do
          # Create another user with confirmed registration in event1
          other_user = create(:user, email: "other-user-#{SecureRandom.hex(4)}@wustl.edu")
          other_reg = create(:event_registration, user: other_user, event_post: event1, status: :confirmed)

          initial_count1 = event1.registrations_count

          delete admin_user_path(target_user), params: { confirmation: 'DELETE' }
          perform_enqueued_jobs

          event1.reload

          # Should only decrease by 1 (target_user's confirmed registration was hard deleted)
          # other_user's registration should remain
          expect(event1.registrations_count).to eq(initial_count1 - 1)
          expect(EventRegistration.find(other_reg.id)).to be_present
        end
      end

      it 'queues deletion as background job' do
        expect {
          delete admin_user_path(target_user), params: { confirmation: 'DELETE' }
        }.to have_enqueued_job(AdminDeletionJob).with(
          'User',
          target_user.id,
          admin.id,
          'Deleted by admin'
        )
      end

      it 'returns async flag in response' do
        delete admin_user_path(target_user), params: { confirmation: 'DELETE' }
        json = JSON.parse(response.body)
        expect(json['async']).to be true
        expect(json['message']).to include('queued')
      end

      it 'includes deletion reason in audit log' do
        delete admin_user_path(target_user), params: {
          confirmation: 'DELETE',
          reason: 'Spam account'
        }

        log = AdminAuditLog.last
        expect(log.metadata['reason']).to eq('Spam account')
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

      it 'hard deletes event with valid confirmation' do
        event_id = event_post.id
        delete admin_event_post_path(event_post), params: {
          confirmation: 'DELETE',
          reason: 'Inappropriate content'
        }

        expect(response).to have_http_status(:success)
        
        # Execute the enqueued job to perform the actual deletion
        perform_enqueued_jobs
        
        # Record should be hard deleted (not found)
        expect { EventPost.find(event_id) }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'cascades deletion to registrations' do
        registration = create(:event_registration, event_post: event_post)
        event_id = event_post.id
        registration_id = registration.id
        delete admin_event_post_path(event_post), params: { confirmation: 'DELETE' }

        # Execute the enqueued job to perform the actual deletion
        perform_enqueued_jobs

        # Records should be hard deleted (not found)
        expect { EventPost.find(event_id) }.to raise_error(ActiveRecord::RecordNotFound)
        expect { EventRegistration.find(registration_id) }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'queues deletion as background job' do
        expect {
          delete admin_event_post_path(event_post), params: { confirmation: 'DELETE' }
        }.to have_enqueued_job(AdminDeletionJob).with(
          'EventPost',
          event_post.id,
          admin.id,
          'Deleted by admin'
        )
      end
    end
  end

  describe 'async deletion behavior' do
    before { sign_in admin }

    it 'returns immediately without waiting for deletion' do
      start_time = Time.current
      delete admin_user_path(target_user), params: { confirmation: 'DELETE' }
      elapsed = Time.current - start_time

      # Should return quickly (less than 1 second)
      expect(elapsed).to be < 1
      expect(response).to have_http_status(:success)
    end

      it 'processes deletion in background job' do
        user_id = target_user.id
        delete admin_user_path(target_user), params: { confirmation: 'DELETE' }
        
        # Initially not deleted (job not processed yet)
        expect(User.find(user_id)).to be_present
        
        # Process the enqueued job
        perform_enqueued_jobs
        
        # Now should be hard deleted (not found)
        expect { User.find(user_id) }.to raise_error(ActiveRecord::RecordNotFound)
      end
  end

end

