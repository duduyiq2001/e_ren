require 'rails_helper'

RSpec.describe "Event Registration Emails", type: :request do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:organizer) { create(:user) }

  before do
    sign_in user
    clear_emails
  end

  describe "registration confirmation emails" do
    context "when event does NOT require approval" do
      let(:event) { create(:event_post, organizer: organizer, requires_approval: false) }

      it "sends confirmation email immediately on registration" do
        perform_enqueued_jobs do
          post event_post_event_registrations_path(event)
        end

        expect(ActionMailer::Base.deliveries.count).to eq(1)
        email = last_email
        expect(email.to).to include(user.email)
        expect(email.subject).to include("Event Enrollment Confirmation")
      end
    end

    context "when event requires approval" do
      let(:approval_event) { create(:event_post, organizer: organizer, requires_approval: true) }

      it "does NOT send email when registration is pending" do
        perform_enqueued_jobs do
          post event_post_event_registrations_path(approval_event)
        end

        expect(ActionMailer::Base.deliveries).to be_empty
      end

      it "sends email when pending registration is approved" do
        registration = create(:event_registration, user: user, event_post: approval_event, status: :pending)
        clear_emails

        perform_enqueued_jobs do
          registration.update!(status: :confirmed)
        end

        expect(ActionMailer::Base.deliveries.count).to eq(1)
        expect(last_email.subject).to include("Event Enrollment Confirmation")
      end
    end

    context "when event is full (waitlisted)" do
      let(:full_event) { create(:event_post, organizer: organizer, capacity: 1) }

      before do
        create(:event_registration, event_post: full_event, status: :confirmed)
      end

      it "sends waitlist confirmation email" do
        perform_enqueued_jobs do
          post event_post_event_registrations_path(full_event)
        end

        expect(ActionMailer::Base.deliveries.count).to eq(1)
        expect(last_email.subject).to include("Waitlist Confirmation")
      end

      it "sends 'You're In' email when promoted from waitlist" do
        waitlisted_reg = create(:event_registration, user: user, event_post: full_event, status: :waitlisted)
        clear_emails

        perform_enqueued_jobs do
          waitlisted_reg.update!(status: :confirmed)
        end

        expect(ActionMailer::Base.deliveries.count).to eq(1)
        expect(last_email.subject).to include("You're In!")
      end
    end
  end
end
