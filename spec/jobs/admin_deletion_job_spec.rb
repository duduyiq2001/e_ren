require 'rails_helper'

RSpec.describe AdminDeletionJob, type: :job do
  include ActiveJob::TestHelper

  let(:admin) { create(:user, :admin, email: "admin-job-test-#{SecureRandom.hex(4)}@wustl.edu") }
  let(:target_user) { create(:user, email: "target-job-test-#{SecureRandom.hex(4)}@wustl.edu") }
  let(:event_post) { create(:event_post) }

  before do
    ActiveJob::Base.queue_adapter = :test
  end

  describe '#perform' do
    context 'when deleting a user' do
      let!(:event) { create(:event_post, organizer: target_user) }
      let!(:registration) { create(:event_registration, user: target_user, event_post: event) }

      it 'hard deletes the user' do
        user_id = target_user.id
        AdminDeletionJob.perform_now('User', target_user.id, admin.id, 'Test reason')
        # User should be hard deleted (not found)
        expect { User.find(user_id) }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'cascades deletion to user events' do
        event_id = event.id
        AdminDeletionJob.perform_now('User', target_user.id, admin.id)
        # Event should be hard deleted (not found)
        expect { EventPost.find(event_id) }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'cascades deletion to user registrations' do
        registration_id = registration.id
        AdminDeletionJob.perform_now('User', target_user.id, admin.id)
        # Registration should be hard deleted (not found)
        expect { EventRegistration.find(registration_id) }.to raise_error(ActiveRecord::RecordNotFound)
      end

      context 'when user has registrations in multiple events' do
        let!(:organizer1) { create(:user, email: "org1-job-#{SecureRandom.hex(4)}@wustl.edu") }
        let!(:organizer2) { create(:user, email: "org2-job-#{SecureRandom.hex(4)}@wustl.edu") }
        let!(:organizer3) { create(:user, email: "org3-job-#{SecureRandom.hex(4)}@wustl.edu") }
        let!(:organizer4) { create(:user, email: "org4-job-#{SecureRandom.hex(4)}@wustl.edu") }
        let!(:organizer5) { create(:user, email: "org5-job-#{SecureRandom.hex(4)}@wustl.edu") }
        
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
        let!(:other_user1) { create(:user, email: "other1-job-#{SecureRandom.hex(4)}@wustl.edu") }
        let!(:other_user2) { create(:user, email: "other2-job-#{SecureRandom.hex(4)}@wustl.edu") }
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
          
          AdminDeletionJob.perform_now('User', target_user.id, admin.id)
          
          event1.reload
          event2.reload
          event3.reload
          event4.reload
          
          # Event1: should decrease by 1 (confirmed_reg1)
          expect(event1.registrations_count).to eq(initial_count1 - 1)
          
          # Event2: should decrease by 1 (confirmed_reg2)
          expect(event2.registrations_count).to eq(initial_count2 - 1)
          
          # Event3: should not change (waitlisted_reg doesn't affect count)
          expect(event3.registrations_count).to eq(initial_count3)
          
          # Event4: should not change (pending_reg doesn't affect count)
          expect(event4.registrations_count).to eq(initial_count4)
        end

        it 'only affects confirmed registrations, not waitlisted or pending' do
          initial_count3 = event3.registrations_count
          initial_count4 = event4.registrations_count
          
          AdminDeletionJob.perform_now('User', target_user.id, admin.id)
          
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
          
          AdminDeletionJob.perform_now('User', target_user.id, admin.id)
          
          event1.reload
          
          # Should only decrease by 1 (target_user's confirmed registration was hard deleted)
          # other_user's registration should remain
          expect(event1.registrations_count).to eq(initial_count1 - 1)
          expect(EventRegistration.find(other_reg.id)).to be_present
        end
      end

      it 'deletes user successfully' do
        user_id = target_user.id
        AdminDeletionJob.perform_now('User', target_user.id, admin.id, 'Spam account')
        # User should be hard deleted (not found)
        expect { User.find(user_id) }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'does not create duplicate audit log entry' do
        # Note: Audit log is created in the controller, not in the job
        # This test verifies that the job doesn't create a duplicate log
        initial_count = AdminAuditLog.count
        AdminDeletionJob.perform_now('User', target_user.id, admin.id)
        # Job should not create a new audit log (controller already did)
        expect(AdminAuditLog.count).to eq(initial_count)
      end
    end

    context 'when deleting an event' do
      let!(:registration1) { create(:event_registration, event_post: event_post) }
      let!(:registration2) { create(:event_registration, event_post: event_post) }

      it 'hard deletes the event' do
        event_id = event_post.id
        AdminDeletionJob.perform_now('EventPost', event_post.id, admin.id)
        # Event should be hard deleted (not found)
        expect { EventPost.find(event_id) }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'cascades deletion to registrations' do
        registration1_id = registration1.id
        registration2_id = registration2.id
        AdminDeletionJob.perform_now('EventPost', event_post.id, admin.id)
        # Registrations should be hard deleted (not found)
        expect { EventRegistration.find(registration1_id) }.to raise_error(ActiveRecord::RecordNotFound)
        expect { EventRegistration.find(registration2_id) }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'deletes event successfully' do
        event_id = event_post.id
        AdminDeletionJob.perform_now('EventPost', event_post.id, admin.id, 'Inappropriate')
        # Event should be hard deleted (not found)
        expect { EventPost.find(event_id) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when record not found' do
      it 'handles missing record gracefully' do
        expect {
          AdminDeletionJob.perform_now('User', 99999, admin.id)
        }.not_to raise_error
      end

      it 'logs error when record not found' do
        expect(Rails.logger).to receive(:error).with(/Record not found/)
        AdminDeletionJob.perform_now('User', 99999, admin.id)
      end
    end

    context 'when error occurs' do
      before do
        allow_any_instance_of(User).to receive(:destroy!).and_raise(StandardError.new('Test error'))
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).at_least(:once)
        expect {
          AdminDeletionJob.perform_now('User', target_user.id, admin.id)
        }.to raise_error(StandardError)
      end

      it 're-raises the error for retry' do
        expect {
          AdminDeletionJob.perform_now('User', target_user.id, admin.id)
        }.to raise_error(StandardError, 'Test error')
      end
    end
  end

  describe 'async execution' do
    it 'enqueues the job' do
      expect {
        AdminDeletionJob.perform_later('User', target_user.id, admin.id)
      }.to have_enqueued_job(AdminDeletionJob)
    end

    it 'passes correct arguments to job' do
      AdminDeletionJob.perform_later('User', target_user.id, admin.id, 'Test reason')
      
      expect(AdminDeletionJob).to have_been_enqueued.with(
        'User',
        target_user.id,
        admin.id,
        'Test reason'
      )
    end
  end
end

