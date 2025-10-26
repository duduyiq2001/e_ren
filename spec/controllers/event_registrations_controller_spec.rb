require 'rails_helper'

RSpec.describe EventRegistrationsController, type: :controller do
  let(:user) { create(:user) }
  let(:event_post) { create(:event_post) }

  before do
    login_user(user)
  end

  describe "POST #create" do
    context "when user is not already registered" do
      it "creates a new registration" do
        expect {
          post :create, params: { event_post_id: event_post.id }
        }.to change(EventRegistration, :count).by(1)
      end

      it "associates the registration with the current user" do
        post :create, params: { event_post_id: event_post.id }
        expect(EventRegistration.last.user).to eq(user)
      end

      it "associates the registration with the event" do
        post :create, params: { event_post_id: event_post.id }
        expect(EventRegistration.last.event_post).to eq(event_post)
      end

      it "redirects to the event page" do
        post :create, params: { event_post_id: event_post.id }
        expect(response).to redirect_to(event_post)
      end

      it "sets a success notice" do
        post :create, params: { event_post_id: event_post.id }
        expect(flash[:notice]).to eq("Successfully registered for the event!")
      end

      it "increments the event's registrations_count" do
        expect {
          post :create, params: { event_post_id: event_post.id }
        }.to change { event_post.reload.registrations_count }.by(1)
      end
    end

    context "when user is already registered" do
      before do
        create(:event_registration, user: user, event_post: event_post)
      end

      it "does not create a new registration" do
        expect {
          post :create, params: { event_post_id: event_post.id }
        }.not_to change(EventRegistration, :count)
      end

      it "redirects to the event page" do
        post :create, params: { event_post_id: event_post.id }
        expect(response).to redirect_to(event_post)
      end

      it "sets an error alert" do
        post :create, params: { event_post_id: event_post.id }
        expect(flash[:alert]).to include("already registered")
      end
    end

    context "when event is full" do
      let(:full_event) { create(:event_post, capacity: 1, registrations_count: 1) }

      before do
        create(:event_registration, event_post: full_event)
      end

      it "creates a registration with waitlisted status" do
        post :create, params: { event_post_id: full_event.id }
        expect(EventRegistration.last.status).to eq("waitlisted")
      end

      it "sets a waitlist notice" do
        post :create, params: { event_post_id: full_event.id }
        expect(flash[:notice]).to eq("Event is full. You've been added to the waitlist.")
      end

      it "still creates the registration" do
        expect {
          post :create, params: { event_post_id: full_event.id }
        }.to change(EventRegistration, :count).by(1)
      end
    end

    context "when not logged in" do
      before do
        session.delete(:user_id)
      end

      it "redirects to login page" do
        post :create, params: { event_post_id: event_post.id }
        expect(response).to redirect_to(login_path)
      end

      it "does not create a registration" do
        expect {
          post :create, params: { event_post_id: event_post.id }
        }.not_to change(EventRegistration, :count)
      end

      it "sets an alert message" do
        post :create, params: { event_post_id: event_post.id }
        expect(flash[:alert]).to eq("You must be logged in to access this page.")
      end
    end
  end

  describe "DELETE #destroy" do
    let!(:registration) { create(:event_registration, user: user, event_post: event_post) }

    context "when destroying own registration" do
      it "destroys the registration" do
        expect {
          delete :destroy, params: { event_post_id: event_post.id, id: registration.id }
        }.to change(EventRegistration, :count).by(-1)
      end

      it "redirects to the event page" do
        delete :destroy, params: { event_post_id: event_post.id, id: registration.id }
        expect(response).to redirect_to(event_post)
      end

      it "sets a success notice" do
        delete :destroy, params: { event_post_id: event_post.id, id: registration.id }
        expect(flash[:notice]).to eq("Successfully unregistered from the event.")
      end

      it "decrements the event's registrations_count" do
        expect {
          delete :destroy, params: { event_post_id: event_post.id, id: registration.id }
        }.to change { event_post.reload.registrations_count }.by(-1)
      end
    end

    context "when trying to destroy another user's registration" do
      let(:other_user) { create(:user) }
      let!(:other_registration) { create(:event_registration, user: other_user, event_post: event_post) }

      it "raises RecordNotFound error" do
        expect {
          delete :destroy, params: { event_post_id: event_post.id, id: other_registration.id }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "does not destroy the registration" do
        expect {
          begin
            delete :destroy, params: { event_post_id: event_post.id, id: other_registration.id }
          rescue ActiveRecord::RecordNotFound
            # Expected error
          end
        }.not_to change(EventRegistration, :count)
      end
    end

    context "when not logged in" do
      before do
        session.delete(:user_id)
      end

      it "redirects to login page" do
        delete :destroy, params: { event_post_id: event_post.id, id: registration.id }
        expect(response).to redirect_to(login_path)
      end

      it "does not destroy the registration" do
        expect {
          delete :destroy, params: { event_post_id: event_post.id, id: registration.id }
        }.not_to change(EventRegistration, :count)
      end

      it "sets an alert message" do
        delete :destroy, params: { event_post_id: event_post.id, id: registration.id }
        expect(flash[:alert]).to eq("You must be logged in to access this page.")
      end
    end
  end

  describe "PATCH #confirm_attendance" do
    let(:organizer) { create(:user) }
    let(:attendee) { create(:user, e_score: 0) }
    let(:past_event) { create(:event_post, organizer: organizer, event_time: 2.hours.ago) }
    let(:future_event) { create(:event_post, organizer: organizer, event_time: 2.hours.from_now) }
    let!(:registration) { create(:event_registration, user: attendee, event_post: past_event, attendance_confirmed: false) }

    context "when organizer confirms attendance for a past event" do
      before do
        login_user(organizer)
      end

      it "updates attendance_confirmed to true" do
        expect {
          patch :confirm_attendance, params: { event_post_id: past_event.id, id: registration.id }
        }.to change { registration.reload.attendance_confirmed }.from(false).to(true)
      end

      it "awards E-points to the attendee" do
        expect {
          patch :confirm_attendance, params: { event_post_id: past_event.id, id: registration.id }
        }.to change { attendee.reload.e_score }.from(0).to(10)
      end

      it "redirects to registrations page" do
        patch :confirm_attendance, params: { event_post_id: past_event.id, id: registration.id }
        expect(response).to redirect_to(registrations_event_post_path(past_event))
      end

      it "sets a success notice with E-points message" do
        patch :confirm_attendance, params: { event_post_id: past_event.id, id: registration.id }
        expect(flash[:notice]).to include("Attendance confirmed!")
        expect(flash[:notice]).to include("earned 10 E-points")
      end
    end

    context "when trying to confirm attendance before event ends" do
      let!(:future_registration) { create(:event_registration, user: attendee, event_post: future_event, attendance_confirmed: false) }

      before do
        login_user(organizer)
      end

      it "does not update attendance_confirmed" do
        expect {
          patch :confirm_attendance, params: { event_post_id: future_event.id, id: future_registration.id }
        }.not_to change { future_registration.reload.attendance_confirmed }
      end

      it "redirects to registrations page" do
        patch :confirm_attendance, params: { event_post_id: future_event.id, id: future_registration.id }
        expect(response).to redirect_to(registrations_event_post_path(future_event))
      end

      it "sets an error alert" do
        patch :confirm_attendance, params: { event_post_id: future_event.id, id: future_registration.id }
        expect(flash[:alert]).to eq("Cannot confirm attendance before the event ends.")
      end
    end

    context "when non-organizer tries to confirm attendance" do
      let(:other_user) { create(:user) }

      before do
        login_user(other_user)
      end

      it "does not update attendance_confirmed" do
        expect {
          patch :confirm_attendance, params: { event_post_id: past_event.id, id: registration.id }
        }.not_to change { registration.reload.attendance_confirmed }
      end

      it "redirects to event page" do
        patch :confirm_attendance, params: { event_post_id: past_event.id, id: registration.id }
        expect(response).to redirect_to(past_event)
      end

      it "sets an authorization error alert" do
        patch :confirm_attendance, params: { event_post_id: past_event.id, id: registration.id }
        expect(flash[:alert]).to eq("You are not authorized to confirm attendance.")
      end
    end

    context "when not logged in" do
      before do
        session.delete(:user_id)
      end

      it "redirects to login page" do
        patch :confirm_attendance, params: { event_post_id: past_event.id, id: registration.id }
        expect(response).to redirect_to(login_path)
      end

      it "does not update attendance_confirmed" do
        expect {
          patch :confirm_attendance, params: { event_post_id: past_event.id, id: registration.id }
        }.not_to change { registration.reload.attendance_confirmed }
      end

      it "sets an alert message" do
        patch :confirm_attendance, params: { event_post_id: past_event.id, id: registration.id }
        expect(flash[:alert]).to eq("You must be logged in to access this page.")
      end
    end
  end
end
