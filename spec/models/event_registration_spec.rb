require 'rails_helper'
require 'pry-byebug'

RSpec.describe EventRegistration, type: :model do
  describe "associations" do
    it { should belong_to(:user) }
    it { should belong_to(:event_post) }
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
    let(:event_post) { create(:event_post).tap { |e| e.update_column(:event_time, 2.hours.ago) } }
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
        registration.update(status: :waitlisted)
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

    it "defaults status to pending" do
      event_post = create(:event_post, requires_approval: true)
      registration = create(:event_registration, event_post: event_post)
      expect(registration.status).to eq("pending")
    end

    it "auto-confirms status if event doesn't require approval" do
      event_post = create(:event_post, requires_approval: false)
      registration = create(:event_registration, event_post: event_post)
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

  describe "when event doesn't require approval" do
    let(:event_post) { create(:event_post, requires_approval: false, capacity: 2, registrations_count: 0) }

    describe "registration creation" do
      it "auto-confirms registration on create" do
        registration = create(:event_registration, event_post: event_post)
        expect(registration.status).to eq("confirmed")
      end

      it "increments counter when registration is created" do
        expect {
          create(:event_registration, event_post: event_post)
        }.to change { event_post.reload.registrations_count }.by(1)
      end
    end

    describe "waitlist behavior" do
      before do
        create(:event_registration, event_post: event_post, status: :confirmed)
        create(:event_registration, event_post: event_post, status: :confirmed)
        event_post.reload
      end

      it "sets registration to waitlisted when event is full" do
        waitlisted_registration = create(:event_registration, event_post: event_post)
        expect(waitlisted_registration.status).to eq("waitlisted")
      end

      it "does not increment counter for waitlisted registration" do
        expect {
          create(:event_registration, event_post: event_post)
        }.not_to change { event_post.reload.registrations_count }
      end
   end

    describe "waitlist promotion" do
      let!(:reg1) { create(:event_registration, event_post: event_post, status: :confirmed) }
      let!(:reg2) { create(:event_registration, event_post: event_post, status: :confirmed) }
      let!(:waitlisted1) { create(:event_registration, event_post: event_post, status: :waitlisted) }
      let!(:waitlisted2) { create(:event_registration, event_post: event_post, status: :waitlisted) }

      before { event_post.reload }

      it "promotes oldest waitlisted user when confirmed registration is cancelled" do
        reg1.destroy

        expect(waitlisted1.reload.status).to eq("confirmed")
        expect(waitlisted2.reload.status).to eq("waitlisted")
      end

      it "increments counter when waitlisted user is promoted" do
        initial_count = event_post.registrations_count

        expect {
          reg1.destroy
        }.to change { event_post.reload.registrations_count }.by(0) # -1 from destroy, +1 from promotion
      end
    end

    describe "registration cancellation" do
      it "decrements counter when confirmed registration is destroyed" do
        registration = create(:event_registration, event_post: event_post, status: :confirmed)
        event_post.reload

        expect {
          registration.destroy
        }.to change { event_post.reload.registrations_count }.by(-1)
      end

      it "does not decrement counter when waitlisted registration is destroyed" do
        create(:event_registration, event_post: event_post, status: :confirmed)
        create(:event_registration, event_post: event_post, status: :confirmed)
        event_post.reload

        waitlisted = create(:event_registration, event_post: event_post, status: :waitlisted)

        expect {
          waitlisted.destroy
        }.not_to change { event_post.reload.registrations_count }
      end
    end
  end

  describe "when event requires approval" do
    let(:event_post) { create(:event_post, requires_approval: true, capacity: 2, registrations_count: 0) }

    describe "registration creation" do
      it "creates registration as pending" do
        registration = create(:event_registration, event_post: event_post)
        expect(registration.status).to eq("pending")
      end

      it "does not increment counter when pending registration is created" do
        expect {
          create(:event_registration, event_post: event_post)
        }.not_to change { event_post.reload.registrations_count }
      end
    end

    describe "approval workflow" do
      it "increments counter when pending registration is approved" do
        registration = create(:event_registration, event_post: event_post, status: :pending)

        expect {
          registration.update(status: :confirmed)
        }.to change { event_post.reload.registrations_count }.by(1)
      end

      it "changes status from pending to confirmed" do
        registration = create(:event_registration, event_post: event_post, status: :pending)

        registration.update(status: :confirmed)

        expect(registration.reload.status).to eq("confirmed")
      end
    end

    describe "waitlist behavior" do
      before do
        create(:event_registration, event_post: event_post, status: :confirmed)
        create(:event_registration, event_post: event_post, status: :confirmed)
        event_post.reload
      end

      it "sets registration to waitlisted when event is full" do
        waitlisted_registration = create(:event_registration, event_post: event_post)
        expect(waitlisted_registration.status).to eq("waitlisted")
      end

      it "does not increment counter for waitlisted registration" do
        expect {
          create(:event_registration, event_post: event_post)
        }.not_to change { event_post.reload.registrations_count }
      end
    end

    describe "waitlist promotion" do
      let!(:reg1) { create(:event_registration, event_post: event_post, status: :confirmed) }
      let!(:reg2) { create(:event_registration, event_post: event_post, status: :confirmed) }
      let!(:waitlisted1) { create(:event_registration, event_post: event_post, status: :waitlisted) }
      let!(:waitlisted2) { create(:event_registration, event_post: event_post, status: :waitlisted) }

      before { event_post.reload }

      it "does not auto-promote when confirmed registration is cancelled" do
        reg1.destroy

        expect(waitlisted1.reload.status).to eq("waitlisted")
        expect(waitlisted2.reload.status).to eq("waitlisted")
      end

      it "can be manually promoted from waitlist to confirmed" do
        waitlisted1.update(status: :confirmed)

        expect(waitlisted1.reload.status).to eq("confirmed")
      end
    end

    describe "registration cancellation" do
      it "decrements counter when confirmed registration is destroyed" do
        registration = create(:event_registration, event_post: event_post, status: :confirmed)
        event_post.reload

        expect {
          registration.destroy
        }.to change { event_post.reload.registrations_count }.by(-1)
      end

      it "does not decrement counter when pending registration is destroyed" do
        registration = create(:event_registration, event_post: event_post, status: :pending)

        expect {
          registration.destroy
        }.not_to change { event_post.reload.registrations_count }
      end
    end
  end
end
