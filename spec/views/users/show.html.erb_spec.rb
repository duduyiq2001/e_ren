require 'rails_helper'

RSpec.describe "users/show.html.erb", type: :view do
  let(:user) { create(:user, e_score: 50) }
  let(:category) { create(:event_category, name: "Sports") }
  let(:organizer) { create(:user, :organizer) }

  before do
    assign(:user, user)
    assign(:stats, {
      total_attended: 5,
      total_organized: 3,
      e_points: 50
    })
    # Stub controller helper methods as external dependencies
    without_partial_double_verification do
      allow(view).to receive(:current_user).and_return(user)
      allow(view).to receive(:logged_in?).and_return(true)
    end
  end

  context "when viewing registered events with confirmed registrations" do
    let!(:event1) do
      create(:event_post,
        name: "Soccer Game",
        event_category: category,
        organizer: organizer,
        event_time: 2.days.from_now,
        location_name: "Stadium"
      )
    end

    let!(:event2) do
      create(:event_post,
        name: "Basketball Tournament",
        event_category: category,
        organizer: organizer,
        event_time: 3.days.from_now,
        location_name: "Gym"
      )
    end

    before do
      create(:event_registration, user: user, event_post: event1, status: :confirmed)
      create(:event_registration, user: user, event_post: event2, status: :confirmed)

      assign(:event_filter, 'registered')
      assign(:confirmed_registrations, [event1, event2])
      assign(:pending_registrations, [])
      assign(:filtered_events, [event1, event2])
      render
    end

    it "displays confirmed registrations header" do
      expect(rendered).to have_content("Confirmed")
    end

    it "displays confirmed event names" do
      expect(rendered).to have_content("Soccer Game")
      expect(rendered).to have_content("Basketball Tournament")
    end

    it "shows confirmed badges" do
      expect(rendered).to have_content("✓ Confirmed")
    end

    it "does not show pending approval header" do
      expect(rendered).not_to have_content("Pending Approval")
    end
  end

  context "when viewing registered events with pending registrations" do
    let!(:approval_event1) do
      create(:event_post,
        name: "Exclusive Workshop",
        event_category: category,
        organizer: organizer,
        event_time: 2.days.from_now,
        location_name: "Conference Room",
        requires_approval: true
      )
    end

    let!(:approval_event2) do
      create(:event_post,
        name: "VIP Dinner",
        event_category: category,
        organizer: organizer,
        event_time: 3.days.from_now,
        location_name: "Restaurant",
        requires_approval: true
      )
    end

    before do
      create(:event_registration, user: user, event_post: approval_event1, status: :pending)
      create(:event_registration, user: user, event_post: approval_event2, status: :pending)

      assign(:event_filter, 'registered')
      assign(:confirmed_registrations, [])
      assign(:pending_registrations, [approval_event1, approval_event2])
      assign(:filtered_events, [approval_event1, approval_event2])
      render
    end

    it "displays pending approval header" do
      expect(rendered).to have_content("Pending Approval")
    end

    it "displays pending event names" do
      expect(rendered).to have_content("Exclusive Workshop")
      expect(rendered).to have_content("VIP Dinner")
    end

    it "shows pending approval badges" do
      expect(rendered).to have_content("⏱ Pending")
    end

    it "does not show confirmed registrations header when no confirmed registrations" do
      # The "Confirmed" header won't appear when there are no confirmed registrations
      # but "Confirmed" may appear in other contexts, so we check the specific section
      expect(rendered).not_to have_selector("h4", text: "Confirmed")
    end
  end

  context "when viewing registered events with both confirmed and pending" do
    let!(:confirmed_event) do
      create(:event_post,
        name: "Soccer Game",
        event_category: category,
        organizer: organizer,
        event_time: 2.days.from_now,
        location_name: "Stadium"
      )
    end

    let!(:pending_event) do
      create(:event_post,
        name: "VIP Dinner",
        event_category: category,
        organizer: organizer,
        event_time: 3.days.from_now,
        location_name: "Restaurant",
        requires_approval: true
      )
    end

    before do
      create(:event_registration, user: user, event_post: confirmed_event, status: :confirmed)
      create(:event_registration, user: user, event_post: pending_event, status: :pending)

      assign(:event_filter, 'registered')
      assign(:confirmed_registrations, [confirmed_event])
      assign(:pending_registrations, [pending_event])
      assign(:filtered_events, [confirmed_event, pending_event])
      render
    end

    it "displays both confirmed and pending headers" do
      expect(rendered).to have_selector("h4", text: "Confirmed")
      expect(rendered).to have_content("Pending Approval")
    end

    it "displays both confirmed and pending events" do
      expect(rendered).to have_content("Soccer Game")
      expect(rendered).to have_content("VIP Dinner")
    end

    it "shows correct badges for each type" do
      expect(rendered).to have_content("✓ Confirmed")
      expect(rendered).to have_content("⏱ Pending")
    end
  end

  context "when viewing registered events with no registrations" do
    before do
      assign(:event_filter, 'registered')
      assign(:confirmed_registrations, [])
      assign(:pending_registrations, [])
      assign(:filtered_events, [])
      render
    end

    it "displays no events message" do
      expect(rendered).to have_content("No registered events")
    end

    it "does not show confirmed header" do
      expect(rendered).not_to have_selector("h4", text: "Confirmed")
    end

    it "does not show pending header" do
      expect(rendered).not_to have_content("Pending Approval")
    end
  end

  context "when viewing organized events" do
    let!(:organized_event) do
      create(:event_post,
        name: "My Event",
        event_category: category,
        organizer: user,
        event_time: 2.days.from_now,
        location_name: "Venue",
        capacity: 50,
        registrations_count: 10
      )
    end

    before do
      assign(:event_filter, 'organized')
      assign(:filtered_events, [organized_event])
      render
    end

    it "displays organized event name" do
      expect(rendered).to have_content("My Event")
    end

    it "shows attendee count" do
      expect(rendered).to have_content("Registered: 10 / 50")
    end

    it "shows view registrations link" do
      expect(rendered).to have_link("Registrations")
    end

    it "shows edit link" do
      expect(rendered).to have_link("Edit")
    end
  end
end
