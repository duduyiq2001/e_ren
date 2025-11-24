require 'rails_helper'

RSpec.describe AdminAuditLog, type: :model do
  let(:admin) { create(:user, :admin) }

  describe 'associations' do
    it { should belong_to(:admin_user).class_name('User') }
  end

  describe 'validations' do
    it { should validate_presence_of(:action) }
    it { should validate_presence_of(:target_type) }
    it { should validate_presence_of(:target_id) }
  end

  describe 'scopes' do
    let!(:log1) { create(:admin_audit_log, action: 'delete', created_at: 1.day.ago) }
    let!(:log2) { create(:admin_audit_log, action: 'restore', created_at: 2.days.ago) }
    let!(:log3) { create(:admin_audit_log, action: 'delete', admin_user: admin, created_at: 3.days.ago) }

    describe '.recent' do
      it 'returns logs ordered by created_at desc' do
        recent_logs = AdminAuditLog.recent
        expect(recent_logs.first).to eq(log1)
        expect(recent_logs.last).to eq(log3)
      end

      it 'limits to 100 records' do
        create_list(:admin_audit_log, 105)
        expect(AdminAuditLog.recent.count).to eq(100)
      end
    end

    describe '.by_admin' do
      it 'returns logs for specific admin' do
        logs = AdminAuditLog.by_admin(admin.id)
        expect(logs).to include(log3)
        expect(logs).not_to include(log1, log2)
      end
    end

    describe '.deletions' do
      it 'returns only deletion logs' do
        deletions = AdminAuditLog.deletions
        expect(deletions).to include(log1, log3)
        expect(deletions).not_to include(log2)
      end
    end

    describe '.restorations' do
      it 'returns only restoration logs' do
        restorations = AdminAuditLog.restorations
        expect(restorations).to include(log2)
        expect(restorations).not_to include(log1, log3)
      end
    end
  end

  describe 'metadata storage' do
    it 'stores JSON metadata' do
      log = AdminAuditLog.create!(
        admin_user: admin,
        action: 'delete',
        target_type: 'User',
        target_id: 1,
        metadata: { reason: 'Spam', preview: { events: 5 } }
      )

      expect(log.metadata['reason']).to eq('Spam')
      expect(log.metadata['preview']['events']).to eq(5)
    end
  end
end

