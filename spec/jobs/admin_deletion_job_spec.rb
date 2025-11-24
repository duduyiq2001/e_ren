require 'rails_helper'

RSpec.describe AdminDeletionJob, type: :job do
  include ActiveJob::TestHelper

  let(:admin) { create(:user, :admin) }
  let(:target_user) { create(:user) }
  let(:event_post) { create(:event_post) }

  before do
    ActiveJob::Base.queue_adapter = :test
  end

  describe '#perform' do
    context 'when deleting a user' do
      let!(:event) { create(:event_post, organizer: target_user) }
      let!(:registration) { create(:event_registration, user: target_user, event_post: event) }

      it 'soft deletes the user' do
        expect {
          AdminDeletionJob.perform_now('User', target_user.id, admin.id, 'Test reason')
        }.to change { target_user.reload.discarded? }.from(false).to(true)
      end

      it 'cascades deletion to user events' do
        AdminDeletionJob.perform_now('User', target_user.id, admin.id)
        expect(event.reload.discarded?).to be true
      end

      it 'cascades deletion to user registrations' do
        AdminDeletionJob.perform_now('User', target_user.id, admin.id)
        expect(registration.reload.discarded?).to be true
      end

      it 'records deletion metadata' do
        AdminDeletionJob.perform_now('User', target_user.id, admin.id, 'Spam account')
        target_user.reload
        expect(target_user.deleted_by_id).to eq(admin.id)
        expect(target_user.deletion_reason).to eq('Spam account')
      end

      it 'creates audit log entry' do
        expect {
          AdminDeletionJob.perform_now('User', target_user.id, admin.id)
        }.to change(AdminAuditLog, :count).by(1)

        log = AdminAuditLog.last
        expect(log.action).to eq('delete')
        expect(log.admin_user).to eq(admin)
        expect(log.target_type).to eq('User')
      end
    end

    context 'when deleting an event' do
      let!(:registration1) { create(:event_registration, event_post: event_post) }
      let!(:registration2) { create(:event_registration, event_post: event_post) }

      it 'soft deletes the event' do
        expect {
          AdminDeletionJob.perform_now('EventPost', event_post.id, admin.id)
        }.to change { event_post.reload.discarded? }.from(false).to(true)
      end

      it 'cascades deletion to registrations' do
        AdminDeletionJob.perform_now('EventPost', event_post.id, admin.id)
        expect(registration1.reload.discarded?).to be true
        expect(registration2.reload.discarded?).to be true
      end

      it 'records deletion metadata' do
        AdminDeletionJob.perform_now('EventPost', event_post.id, admin.id, 'Inappropriate')
        event_post.reload
        expect(event_post.deleted_by_id).to eq(admin.id)
        expect(event_post.deletion_reason).to eq('Inappropriate')
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
        allow_any_instance_of(User).to receive(:soft_delete_with_cascade!).and_raise(StandardError.new('Test error'))
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

