require 'rails_helper'

RSpec.describe EventRegistration, type: :model do
  describe "associations" do
    it { should belong_to(:user) }
    it { should belong_to(:event_post).counter_cache(:registrations_count) }
  end

  describe "validations" do
    it "validates uniqueness of user_id scoped to event_post_id" do
      user = create(:user)
      event_post = create(:event_post)
      create(:event_registration, user: user, event_post: event_post)

      duplicate_registration = build(:event_registration, user: user, event_post: event_post)
      expect(duplicate_registration).not_to be_valid
      expect(duplicate_registration.errors[:user_id]).to include("has already registered for this event")
    end
  end

  describe "attendance confirmation and E-score" do
    let(:user) { create(:user, e_score: 0) }
    let(:event_post) { create(:event_post, event_time: 2.hours.ago) }
    let(:registration) { create(:event_registration, user: user, event_post: event_post, attendance_confirmed: false) }

    it "awards 10 E-points when attendance is confirmed" do
      expect {
        registration.update(attendance_confirmed: true)
      }.to change { user.reload.e_score }.from(0).to(10)
    end

    it "does not award E-points if attendance_confirmed doesn't change" do
      registration.update(attendance_confirmed: true)
      user.reload
      initial_score = user.e_score

      expect {
        registration.update(status: :cancelled)
      }.not_to change { user.reload.e_score }
    end

    it "does not award E-points if attendance_confirmed is set to false" do
      registration.update(attendance_confirmed: true)
      user.reload
      initial_score = user.e_score

      expect {
        registration.update(attendance_confirmed: false)
      }.not_to change { user.reload.e_score }
    end

    it "awards E-points only once when attendance is confirmed multiple times" do
      registration.update(attendance_confirmed: true)
      user.reload
      expect(user.e_score).to eq(10)

      # Try to confirm again (shouldn't award more points since it's already true)
      registration.update(attendance_confirmed: true)
      user.reload
      expect(user.e_score).to eq(10)
    end
  end

  describe "default values" do
    it "defaults attendance_confirmed to false" do
      registration = create(:event_registration)
      expect(registration.attendance_confirmed).to eq(false)
    end

    it "defaults status to confirmed" do
      registration = create(:event_registration)
      expect(registration.status).to eq("confirmed")
    end
  end

  describe "callbacks" do
    it "sets registered_at on create" do
      registration = build(:event_registration, registered_at: nil)
      registration.save
      expect(registration.registered_at).to be_present
    end
  end
end
