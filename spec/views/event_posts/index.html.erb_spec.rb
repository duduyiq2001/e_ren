require 'rails_helper'
require 'pry-byebug'

RSpec.describe "event_posts/index.html.erb", type: :view do
  let(:category) { create(:event_category, name: "Sports") }
  let(:organizer) { create(:user, name: "Event Organizer") }
  let(:current_user) { create(:user, name: "Current User") }

  before do
    allow(view).to receive(:current_user).and_return(current_user)
  end

  context "with multiple events" do
    let!(:event1) do
      create(:event_post,
        name: "Basketball Game",
        event_category: category,
        organizer: organizer,
        event_time: 1.day.from_now
      )
    end

    let!(:event2) do
      create(:event_post,
        name: "Study Session",
        event_category: category,
        organizer: organizer,
        event_time: 2.days.from_now
      )
    end

    before do
      assign(:event_posts, [event1, event2])
      assign(:user_registrations, {})
      render
    end

    it "displays page title" do
      expect(rendered).to have_content("Discover Campus Events")
    end

    it "displays all event names" do
      expect(rendered).to have_content("Basketball Game")
      expect(rendered).to have_content("Study Session")
    end

    it "displays event count" do
      expect(rendered).to have_content("Upcoming Events (2)")
    end

    it "shows post event button" do
      expect(rendered).to have_link("Post Event")
    end

    it "shows search link" do
      expect(rendered).to have_link(href: search_event_posts_path)
    end

    it "shows user profile avatar" do
      expect(rendered).to have_link(href: user_path(current_user))
    end
  end

  context "with no events" do
    before do
      assign(:event_posts, [])
      assign(:user_registrations, {})
      render
    end

    it "displays zero count" do
      expect(rendered).to have_content("Upcoming Events (0)")
    end

    it "still shows navigation elements" do
      expect(rendered).to have_link("Post Event")
      expect(rendered).to have_content("Discover Campus Events")
    end
  end
end
