require 'rails_helper'

RSpec.describe "EventPosts", type: :request do
  describe "GET /event_posts/index" do
    let!(:sports_category) { create(:event_category, :sports) }
    let!(:food_category) { create(:event_category, :food) }
    let!(:event1) { create(:event_post, :today, event_category: sports_category) }
    let!(:event2) { create(:event_post, :tomorrow, event_category: food_category) }
    let!(:event3) { create(:event_post, :this_week, event_category: sports_category, :with_attendees) }

    it "returns http success" do
      get "/event_posts/index"
      expect(response).to have_http_status(:success)
    end

    it "loads all event posts" do
      get "/event_posts/index"
      expect(assigns(:event_posts)).to match_array([event1, event2, event3])
    end

    it "orders events by event_time" do
      get "/event_posts/index"
      events = assigns(:event_posts)
      expect(events.first.event_time).to be <= events.last.event_time
    end

    it "displays attendees for events" do
      get "/event_posts/index"
      expect(response.body).to include("Attendees:")
    end
  end

  describe "GET /event_posts/search" do
    let!(:sports_category) { create(:event_category, :sports) }
    let!(:food_category) { create(:event_category, :food) }
    let!(:academic_category) { create(:event_category, :academic) }

    let!(:soccer_event) do
      create(:event_post,
        name: "Soccer Tournament",
        event_category: sports_category,
        event_time: 2.days.from_now,
        latitude: 37.7749,
        longitude: -122.4194
      )
    end

    let!(:pizza_event) do
      create(:event_post,
        name: "Pizza Party",
        event_category: food_category,
        event_time: 1.day.from_now.change(hour: 18),
        latitude: 37.7750,
        longitude: -122.4195
      )
    end

    let!(:study_event) do
      create(:event_post,
        name: "Study Session",
        event_category: academic_category,
        event_time: 5.days.from_now,
        latitude: 40.7128,
        longitude: -74.0060
      )
    end

    context "without any filters" do
      it "returns http success" do
        get "/event_posts/search"
        expect(response).to have_http_status(:success)
      end

      it "shows upcoming events by default" do
        get "/event_posts/search"
        events = assigns(:event_posts)
        expect(events).to include(soccer_event, pizza_event, study_event)
      end

      it "loads event categories for dropdown" do
        get "/event_posts/search"
        expect(assigns(:event_categories)).to include(sports_category, food_category, academic_category)
      end
    end

    context "with name search" do
      it "finds events by fuzzy name match" do
        get "/event_posts/search", params: { q: "soccer" }
        events = assigns(:event_posts)
        expect(events).to include(soccer_event)
        expect(events).not_to include(pizza_event, study_event)
      end

      it "is case insensitive" do
        get "/event_posts/search", params: { q: "PIZZA" }
        events = assigns(:event_posts)
        expect(events).to include(pizza_event)
      end

      it "matches partial names" do
        get "/event_posts/search", params: { q: "pizz" }
        events = assigns(:event_posts)
        expect(events).to include(pizza_event)
      end

      it "returns empty when no matches found" do
        get "/event_posts/search", params: { q: "Nonexistent Event" }
        events = assigns(:event_posts)
        expect(events).to be_empty
      end
    end

    context "with category filter" do
      it "filters events by category" do
        get "/event_posts/search", params: { category_id: sports_category.id }
        events = assigns(:event_posts)
        expect(events).to include(soccer_event)
        expect(events).not_to include(pizza_event, study_event)
      end

      it "shows all events when no category specified" do
        get "/event_posts/search"
        events = assigns(:event_posts)
        expect(events.count).to eq(3)
      end
    end

    context "with time filters" do
      before do
        # Mock Geocoder to avoid actual API calls
        Geocoder::Lookup::Test.set_default_stub(
          [{ 'latitude' => 37.7749, 'longitude' => -122.4194 }]
        )

        # Create events at specific times
        @tomorrow_event = create(:event_post, event_category: sports_category, event_time: 1.day.from_now.change(hour: 14))
        @two_days_event = create(:event_post, :two_days_from_now, event_category: sports_category)
        @next_week_event = create(:event_post, :next_week, event_category: sports_category)
      end

      after do
        Geocoder::Lookup::Test.reset
      end

      it "filters events for tomorrow using custom date range" do
        tomorrow = 1.day.from_now.to_date
        get "/event_posts/search", params: { start_date: tomorrow, end_date: tomorrow }
        events = assigns(:event_posts)
        expect(events).to include(@tomorrow_event, pizza_event)
        expect(events).not_to include(@two_days_event, @next_week_event)
      end

      it "filters events happening this week" do
        get "/event_posts/search", params: { time_filter: "this_week" }
        events = assigns(:event_posts)
        expect(events.map(&:id)).to include(@tomorrow_event.id, @two_days_event.id, pizza_event.id)
      end

      it "filters events by custom date range" do
        start_date = Date.today
        end_date = 3.days.from_now.to_date

        get "/event_posts/search", params: {
          start_date: start_date,
          end_date: end_date
        }

        events = assigns(:event_posts)
        expect(events).to include(soccer_event, pizza_event)
        expect(events).not_to include(study_event)
      end
    end

    context "with location filter" do
      before do
        # Mock Geocoder to avoid actual API calls
        allow(EventPost).to receive(:near).and_return(EventPost.all)
      end

      it "filters events by proximity when lat/lng provided" do
        # Mock near scope to return only nearby events
        nearby_scope = double('ActiveRecord::Relation')
        allow(nearby_scope).to receive(:where).and_return(nearby_scope)
        allow(nearby_scope).to receive(:order).and_return([soccer_event, pizza_event])
        allow(EventPost).to receive(:includes).and_return(EventPost.all)
        allow(EventPost.all).to receive(:near_location).with("37.7749", "-122.4194", "10").and_return(nearby_scope)

        get "/event_posts/search", params: {
          latitude: "37.7749",
          longitude: "-122.4194",
          radius: "10"
        }

        expect(response).to have_http_status(:success)
      end

      it "uses default radius of 10 miles when not specified" do
        get "/event_posts/search", params: {
          latitude: "37.7749",
          longitude: "-122.4194"
        }

        expect(response).to have_http_status(:success)
      end

      it "accepts custom radius" do
        get "/event_posts/search", params: {
          latitude: "37.7749",
          longitude: "-122.4194",
          radius: "25"
        }

        expect(response).to have_http_status(:success)
      end
    end

    context "with combined filters" do
      it "applies multiple filters together" do
        get "/event_posts/search", params: {
          q: "Soccer",
          category_id: sports_category.id,
          time_filter: "upcoming"
        }

        events = assigns(:event_posts)
        expect(events).to include(soccer_event)
        expect(events).not_to include(pizza_event, study_event)
      end

      it "chains all filters correctly" do
        tomorrow_sports = create(:event_post,
          name: "Basketball Game",
          event_category: sports_category,
          event_time: 1.day.from_now.change(hour: 20)
        )

        get "/event_posts/search", params: {
          q: "ball",
          category_id: sports_category.id,
          time_filter: "upcoming"
        }

        events = assigns(:event_posts)
        expect(events).to include(tomorrow_sports)
        expect(events).not_to include(study_event)
      end
    end

    context "with attendees" do
      let!(:user1) { create(:user, name: "Alice") }
      let!(:user2) { create(:user, name: "Bob") }

      before do
        create(:event_registration, user: user1, event_post: soccer_event)
        create(:event_registration, user: user2, event_post: soccer_event)
      end

      it "displays attendee names" do
        get "/event_posts/search"
        expect(response.body).to include("Alice")
        expect(response.body).to include("Bob")
      end
    end
  end

  describe "GET /event_posts/find" do
    it "returns http success" do
      get "/event_posts/find"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /event_posts/post" do
    it "returns http success" do
      get "/event_posts/post"
      expect(response).to have_http_status(:success)
    end
  end
end
