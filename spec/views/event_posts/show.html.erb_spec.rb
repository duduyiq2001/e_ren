require 'rails_helper'
require 'pry-byebug'

RSpec.describe "event_posts/show.html.erb", type: :view do
  let(:category) { create(:event_category) }
  let(:organizer) { create(:user, :organizer) }
  let(:attendee) { create(:user, :attendee) }
  let(:event_post) do
    create(:event_post,
      name: "Test Event",
      description: "Test Description",
      location_name: "Test Location",
      capacity: 10,
      registrations_count: 5,
      event_category: category,
      organizer: organizer,
      event_time: 2.days.from_now
    )
  end

  before do
    assign(:event_post, event_post)
    # Stub controller helper methods as external dependencies
    without_partial_double_verification do
      allow(view).to receive(:current_user).and_return(current_user)
      allow(view).to receive(:logged_in?).and_return(true)
    end
  end

  context "when user is not registered" do
    let(:current_user) { attendee }

    before do
      assign(:registration, nil)
      render
    end

    it "displays event name" do
      expect(rendered).to have_content("Test Event")
    end

    it "displays event details" do
      expect(rendered).to have_content("Test Location")
      expect(rendered).to have_content("Test Description")
      expect(rendered).to have_content("5 / 10")
    end

    it "displays organizer name" do
      expect(rendered).to have_content(organizer.name)
    end

    it "shows register button when not full" do
      expect(rendered).to have_button("Register for Event", visible: :all)
    end

    it "hides organizer contact info" do
      expect(rendered).to have_content("Register to view organizer contact")
      expect(rendered).not_to have_content(organizer.email)
    end

    it "does not show unregister button" do
      expect(rendered).not_to have_button("Unregister", visible: :all)
    end
  end

  context "when user is registered" do
    let(:current_user) { attendee }
    let(:registration) { create(:event_registration, user: attendee, event_post: event_post, status: :confirmed) }

    before do
      assign(:registration, registration)
      render
    end

    it "shows registered badge" do
      expect(rendered).to have_content("Registered")
    end

    it "shows unregister button" do
      expect(rendered).to have_button("Unregister", visible: :all)
    end

    it "shows organizer contact info" do
      expect(rendered).to have_content(organizer.email)
      expect(rendered).not_to have_content("Register to view organizer contact")
    end

    it "does not show register button" do
      expect(rendered).not_to have_button("Register for Event", visible: :all)
    end
  end

  context "when user is waitlisted" do
    let(:current_user) { attendee }
    let(:registration) { create(:event_registration, user: attendee, event_post: event_post, status: :waitlisted) }

    before do
      assign(:registration, registration)
      render
    end

    it "shows waitlisted badge" do
      expect(rendered).to have_content("Waitlisted")
    end

    it "shows unregister button" do
      expect(rendered).to have_button("Unregister", visible: :all)
    end
  end

  context "when event is full" do
    let(:current_user) { attendee }
    let(:full_event) do
      create(:event_post,
        capacity: 10,
        registrations_count: 10,
        event_category: category,
        organizer: organizer
      )
    end

    before do
      assign(:event_post, full_event)
      assign(:registration, nil)
      render
    end

    it "shows join waitlist button" do
      expect(rendered).to have_button("Join Waitlist", visible: :all)
    end

    it "does not show register button" do
      expect(rendered).not_to have_button("Register for Event", visible: :all)
    end
  end

  context "when user is the organizer" do
    let(:current_user) { organizer }

    before do
      assign(:registration, nil)
      render
    end

    it "shows organizer action buttons" do
      expect(rendered).to have_link("View Registrations", visible: :all)
      expect(rendered).to have_link("Edit Event", visible: :all)
      expect(rendered).to have_button("Delete Event", visible: :all)
    end
  end

  context "when user is organizer and registered" do
    let(:current_user) { organizer }
    let(:registration) { create(:event_registration, user: organizer, event_post: event_post) }

    before do
      assign(:registration, registration)
      render
    end

    it "shows both registration and organizer actions" do
      expect(rendered).to have_content("Registered")
      expect(rendered).to have_button("Unregister", visible: :all)
      expect(rendered).to have_link("View Registrations", visible: :all)
      expect(rendered).to have_link("Edit Event", visible: :all)
      expect(rendered).to have_button("Delete Event", visible: :all)
    end
  end

  context "when event requires approval" do
    let(:current_user) { attendee }
    let(:approval_event) do
      create(:event_post,
        name: "Exclusive Event",
        description: "Application-based event",
        location_name: "VIP Room",
        capacity: 10,
        registrations_count: 5,
        event_category: category,
        organizer: organizer,
        event_time: 2.days.from_now,
        requires_approval: true
      )
    end

    before do
      assign(:event_post, approval_event)
      assign(:registration, nil)
      render
    end

    it "shows requires approval badge" do
      expect(rendered).to have_content("Requires Approval")
    end

    it "shows approval notice" do
      expect(rendered).to have_content("Registration Requires Approval")
      expect(rendered).to have_content("Your registration will be pending until the organizer reviews and approves it")
    end

    it "still shows register button" do
      expect(rendered).to have_button("Register for Event", visible: :all)
    end
  end

  context "when event does not require approval" do
    let(:current_user) { attendee }

    before do
      assign(:registration, nil)
      render
    end

    it "does not show requires approval badge" do
      expect(rendered).not_to have_content("Requires Approval")
    end

    it "does not show approval notice" do
      expect(rendered).not_to have_content("Registration Requires Approval")
    end
  end
end
