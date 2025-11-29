require 'rails_helper'

RSpec.describe "event_posts/search.html.erb", type: :view do
  let(:category) { create(:event_category) }
  let(:organizer) { create(:user, name: "Event Organizer") }
  let(:current_user) { create(:user, name: "Current User") }

  before do
    without_partial_double_verification do
      allow(view).to receive(:current_user).and_return(current_user)
      allow(view).to receive(:logged_in?).and_return(true)
    end
    assign(:event_categories, [category])
    assign(:user_registrations, {})
  end

  describe "search form" do
    before do
      assign(:event_posts, [])
      render
    end

    it "displays the search form" do
      expect(rendered).to have_selector("form")
      expect(rendered).to have_field("q")
    end

    it "displays category filter dropdown" do
      expect(rendered).to have_select("category_id")
    end

    it "displays time filter dropdown with all options" do
      expect(rendered).to have_select("time_filter", with_options: ["Upcoming", "Today", "This Week", "Custom Range"])
    end

    it "displays radius filter dropdown" do
      expect(rendered).to have_select("radius")
    end

    it "displays registration type filter" do
      expect(rendered).to have_select("requires_approval")
    end

    it "has hidden date range inputs by default" do
      expect(rendered).to have_selector("#date-range-inputs[style*='display: none']", visible: false)
    end

    it "has start_date and end_date fields for custom range" do
      # Fields exist but are hidden by default
      expect(rendered).to have_selector("input#start_date[type='date']", visible: :all)
      expect(rendered).to have_selector("input#end_date[type='date']", visible: :all)
    end

    it "has a search button" do
      expect(rendered).to have_button("Search")
    end

    it "has a clear filters link" do
      expect(rendered).to have_link("Clear Filters")
    end
  end

  describe "with search results" do
    let!(:event) do
      create(:event_post,
        name: "Test Event",
        event_category: category,
        organizer: organizer,
        event_time: 1.day.from_now
      )
    end

    before do
      assign(:event_posts, [event])
      render
    end

    it "displays event count" do
      expect(rendered).to have_content("1 events found")
    end

    it "displays event cards" do
      expect(rendered).to have_content("Test Event")
    end
  end

  describe "with no results" do
    before do
      assign(:event_posts, [])
    end

    context "when search was performed" do
      it "shows no events message when filtering by name" do
        allow(view).to receive(:params).and_return({ q: "nonexistent" })
        render
        expect(rendered).to have_content("No events found")
      end

      it "shows no events message when filtering by category" do
        allow(view).to receive(:params).and_return({ category_id: "999" })
        render
        expect(rendered).to have_content("No events found")
      end
    end

    context "when no search performed" do
      it "shows prompt to use filters" do
        allow(view).to receive(:params).and_return({})
        render
        expect(rendered).to have_content("Use filters above to search for events")
      end
    end
  end

  describe "preserving form values" do
    before do
      assign(:event_posts, [])
    end

    it "preserves search query in input" do
      allow(view).to receive(:params).and_return({ q: "test query" })
      render
      expect(rendered).to have_field("q", with: "test query")
    end

    it "preserves selected category" do
      allow(view).to receive(:params).and_return({ category_id: category.id.to_s })
      render
      expect(rendered).to have_selector("option[value='#{category.id}'][selected]")
    end

    it "preserves custom time filter selection" do
      allow(view).to receive(:params).and_return({ time_filter: "custom" })
      render
      expect(rendered).to have_select("time_filter", selected: "Custom Range")
    end

    it "preserves start_date value" do
      allow(view).to receive(:params).and_return({ start_date: "2025-01-15" })
      render
      expect(rendered).to have_selector("input#start_date[value='2025-01-15']", visible: :all)
    end

    it "preserves end_date value" do
      allow(view).to receive(:params).and_return({ end_date: "2025-01-20" })
      render
      expect(rendered).to have_selector("input#end_date[value='2025-01-20']", visible: :all)
    end
  end
end
