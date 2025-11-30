require 'rails_helper'

RSpec.describe "shared/_event_card.html.erb", type: :view do
  let(:category) { create(:event_category, name: "Sports") }
  let(:organizer) { create(:user, :organizer) }
  let(:event) do
    create(:event_post,
      name: "Soccer Game",
      location_name: "Athletic Field",
      capacity: 20,
      registrations_count: 5,
      event_category: category,
      organizer: organizer,
      event_time: 2.days.from_now
    )
  end

  before do
    without_partial_double_verification do
      allow(view).to receive(:current_user).and_return(create(:user))
      allow(view).to receive(:logged_in?).and_return(true)
    end
  end

  context "basic event card display" do
    before do
      render partial: "shared/event_card", locals: { event: event, registration: nil }
    end

    it "displays event name" do
      expect(rendered).to have_content("Soccer Game")
    end

    it "displays location name" do
      expect(rendered).to have_content("Athletic Field")
    end

    it "displays category name" do
      expect(rendered).to have_content("Sports")
    end

    it "displays registration count" do
      expect(rendered).to have_content("5 / 20 registered")
    end

    it "displays organizer name" do
      expect(rendered).to have_content(organizer.name)
    end

    it "links to event show page" do
      expect(rendered).to have_link("Soccer Game", href: event_post_path(event))
    end

    it "shows register button when not registered" do
      expect(rendered).to have_button("Register", visible: :all)
    end
  end

  context "when event has google_maps_url" do
    let(:event_with_map) do
      create(:event_post,
        name: "Mapped Event",
        location_name: "Test Location",
        google_maps_url: "https://maps.google.com/?q=37.7749,-122.4194",
        event_category: category,
        organizer: organizer
      )
    end

    before do
      render partial: "shared/event_card", locals: { event: event_with_map, registration: nil }
    end

    it "displays location as clickable link" do
      expect(rendered).to have_link("Test Location", href: "https://maps.google.com/?q=37.7749,-122.4194")
    end

    it "opens link in new tab" do
      expect(rendered).to have_css('a[target="_blank"]', text: "Test Location")
    end

    it "has noopener rel attribute for security" do
      expect(rendered).to have_css('a[rel="noopener"]', text: "Test Location")
    end
  end

  context "when event does not have google_maps_url" do
    before do
      event.update!(google_maps_url: nil)
      render partial: "shared/event_card", locals: { event: event, registration: nil }
    end

    it "displays location as plain text" do
      expect(rendered).to have_content("Athletic Field")
      expect(rendered).not_to have_link("Athletic Field")
    end
  end

  context "when user is registered" do
    let(:user) { create(:user) }
    let(:registration) { create(:event_registration, user: user, event_post: event, status: :confirmed) }

    before do
      render partial: "shared/event_card", locals: { event: event, registration: registration }
    end

    it "shows registered badge" do
      expect(rendered).to have_content("Registered")
    end

    it "shows unregister button" do
      expect(rendered).to have_button("Unregister", visible: :all)
    end

    it "does not show register button" do
      expect(rendered).not_to have_button("Register", visible: :all)
    end
  end

  context "when user is waitlisted" do
    let(:user) { create(:user) }
    let(:registration) { create(:event_registration, user: user, event_post: event, status: :waitlisted) }

    before do
      render partial: "shared/event_card", locals: { event: event, registration: registration }
    end

    it "shows waitlisted badge" do
      expect(rendered).to have_content("Waitlisted")
    end

    it "shows unregister button" do
      expect(rendered).to have_button("Unregister", visible: :all)
    end
  end

  context "when event is full" do
    let(:full_event) do
      create(:event_post,
        capacity: 10,
        registrations_count: 10,
        event_category: category,
        organizer: organizer
      )
    end

    before do
      render partial: "shared/event_card", locals: { event: full_event, registration: nil }
    end

    it "shows join waitlist button" do
      expect(rendered).to have_button("Join Waitlist", visible: :all)
    end

    it "does not show register button" do
      expect(rendered).not_to have_button("Register", visible: :all)
    end
  end
end
