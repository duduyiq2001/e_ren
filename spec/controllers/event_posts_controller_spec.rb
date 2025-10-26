require 'rails_helper'

RSpec.describe EventPostsController, type: :controller do
  # Mock Geocoder to avoid API calls
  before(:all) do
    Geocoder::Lookup::Test.set_default_stub(
      [{ 'latitude' => 37.7749, 'longitude' => -122.4194 }]
    )
  end

  after(:all) do
    Geocoder::Lookup::Test.reset
  end

  # Login user before each test
  before do
    login_user
  end

  describe "GET #index" do
    let!(:sports_category) { create(:event_category, :sports) }
    let!(:food_category) { create(:event_category, :food) }
    let!(:event1) { create(:event_post, :today, event_category: sports_category) }
    let!(:event2) { create(:event_post, :tomorrow, event_category: food_category) }
    let!(:event3) { create(:event_post, :this_week, event_category: sports_category) }

    it "returns http success" do
      get :index
      expect(response).to have_http_status(:success)
    end

    it "renders the index template" do
      get :index
      expect(response).to render_template(:index)
    end

    it "assigns @event_posts with all events" do
      get :index
      expect(assigns(:event_posts)).to match_array([event1, event2, event3])
    end

    it "orders events by event_time ascending" do
      get :index
      events = assigns(:event_posts)
      expect(events[0].event_time).to be <= events[1].event_time
      expect(events[1].event_time).to be <= events[2].event_time
    end

    context "user registrations" do
      let(:user) { login_user }

      it "loads user's registrations for displayed events" do
        registration = create(:event_registration, user: user, event_post: event1)

        get :index

        expect(assigns(:user_registrations)).to be_present
        expect(assigns(:user_registrations)[event1.id]).to eq(registration)
      end

      it "indexes registrations by event_post_id for efficient lookup" do
        reg1 = create(:event_registration, user: user, event_post: event1)
        reg2 = create(:event_registration, user: user, event_post: event2)

        get :index

        user_regs = assigns(:user_registrations)
        expect(user_regs[event1.id]).to eq(reg1)
        expect(user_regs[event2.id]).to eq(reg2)
        expect(user_regs[event3.id]).to be_nil
      end

      it "only loads registrations for the current user" do
        other_user = create(:user)
        create(:event_registration, user: other_user, event_post: event1)
        user_reg = create(:event_registration, user: user, event_post: event2)

        get :index

        user_regs = assigns(:user_registrations)
        expect(user_regs[event1.id]).to be_nil
        expect(user_regs[event2.id]).to eq(user_reg)
      end
    end
  end

  describe "GET #search" do
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

    it "returns http success" do
      get :search
      expect(response).to have_http_status(:success)
    end

    it "renders the search template" do
      get :search
      expect(response).to render_template(:search)
    end

    context "without any parameters" do
      it "assigns @event_posts with upcoming events by default" do
        get :search
        events = assigns(:event_posts)
        expect(events).to include(soccer_event, pizza_event, study_event)
      end

      it "assigns @event_categories" do
        get :search
        expect(assigns(:event_categories)).to include(sports_category, food_category, academic_category)
      end
    end

    context "with name search parameter" do
      it "filters events by name query" do
        get :search, params: { q: "soccer" }
        events = assigns(:event_posts)
        expect(events).to include(soccer_event)
        expect(events).not_to include(pizza_event, study_event)
      end

      it "performs case-insensitive search" do
        get :search, params: { q: "PIZZA" }
        events = assigns(:event_posts)
        expect(events).to include(pizza_event)
      end

      it "handles partial name matches" do
        get :search, params: { q: "pizz" }
        events = assigns(:event_posts)
        expect(events).to include(pizza_event)
      end

      it "returns empty result when no matches" do
        get :search, params: { q: "Nonexistent Event" }
        events = assigns(:event_posts)
        expect(events).to be_empty
      end
    end

    context "with category_id parameter" do
      it "filters events by category" do
        get :search, params: { category_id: sports_category.id }
        events = assigns(:event_posts)
        expect(events).to include(soccer_event)
        expect(events).not_to include(pizza_event, study_event)
      end

      it "ignores blank category_id" do
        get :search, params: { category_id: "" }
        events = assigns(:event_posts)
        expect(events.count).to eq(3)
      end
    end

    context "with time_filter parameter" do
      before do
        # Mock Geocoder to avoid actual API calls
        Geocoder::Lookup::Test.set_default_stub(
          [{ 'latitude' => 37.7749, 'longitude' => -122.4194 }]
        )
      end

      after do
        Geocoder::Lookup::Test.reset
      end

      let!(:tomorrow_event) { create(:event_post, event_category: sports_category, event_time: 1.day.from_now.change(hour: 14)) }
      let!(:two_days_event) { create(:event_post, :two_days_from_now, event_category: sports_category) }
      let!(:next_week_event) { create(:event_post, :next_week, event_category: sports_category) }

      it "filters events for tomorrow using custom date range" do
        tomorrow = 1.day.from_now.to_date
        get :search, params: { start_date: tomorrow, end_date: tomorrow }
        events = assigns(:event_posts)
        expect(events).to include(pizza_event, tomorrow_event)
        expect(events).not_to include(two_days_event, next_week_event)
      end

    end

    context "with custom date range" do
      it "filters events between start_date and end_date" do
        start_date = Date.today
        end_date = 3.days.from_now.to_date

        get :search, params: {
          start_date: start_date,
          end_date: end_date
        }

        events = assigns(:event_posts)
        expect(events).to include(soccer_event, pizza_event)
        expect(events).not_to include(study_event)
      end

      it "falls back to upcoming when only start_date provided" do
        get :search, params: { start_date: Date.today }
        events = assigns(:event_posts)
        expect(events).to include(soccer_event, pizza_event, study_event)
      end

      it "falls back to upcoming when only end_date provided" do
        get :search, params: { end_date: 10.days.from_now }
        events = assigns(:event_posts)
        expect(events).to include(soccer_event, pizza_event, study_event)
      end
    end

    context "with location parameters" do
      it "filters events by proximity when lat/lng provided" do
        get :search, params: {
          latitude: "37.7749",
          longitude: "-122.4194",
          radius: "10"
        }

        events = assigns(:event_posts)
        expect(events).to include(soccer_event, pizza_event)
        expect(events).not_to include(study_event)
      end

      it "uses default radius of 10 miles when not specified" do
        get :search, params: {
          latitude: "37.7749",
          longitude: "-122.4194"
        }

        expect(response).to have_http_status(:success)
        expect(assigns(:event_posts)).to be_present
      end

      it "ignores location filter when latitude missing" do
        get :search, params: {
          longitude: "-122.4194",
          radius: "10"
        }

        events = assigns(:event_posts)
        expect(events.count).to eq(3)
      end

      it "ignores location filter when longitude missing" do
        get :search, params: {
          latitude: "37.7749",
          radius: "10"
        }

        events = assigns(:event_posts)
        expect(events.count).to eq(3)
      end
    end

    context "with combined filters" do
      it "applies name search and category filter together" do
        get :search, params: {
          q: "Soccer",
          category_id: sports_category.id,
          time_filter: "upcoming"
        }

        events = assigns(:event_posts)
        expect(events).to include(soccer_event)
        expect(events).not_to include(pizza_event, study_event)
      end

      it "chains multiple filters correctly" do
        tomorrow_sports = create(:event_post,
          name: "Basketball Game",
          event_category: sports_category,
          event_time: 1.day.from_now.change(hour: 20)
        )

        get :search, params: {
          q: "ball",
          category_id: sports_category.id,
          time_filter: "upcoming"
        }

        events = assigns(:event_posts)
        expect(events).to include(tomorrow_sports)
        expect(events).not_to include(soccer_event, study_event)
      end
    end

    context "user registrations" do
      let(:user) { login_user }

      it "loads user's registrations for search results" do
        registration = create(:event_registration, user: user, event_post: soccer_event)

        get :search

        expect(assigns(:user_registrations)).to be_present
        expect(assigns(:user_registrations)[soccer_event.id]).to eq(registration)
      end

      it "indexes registrations by event_post_id for efficient lookup" do
        reg1 = create(:event_registration, user: user, event_post: soccer_event)
        reg2 = create(:event_registration, user: user, event_post: pizza_event)

        get :search

        user_regs = assigns(:user_registrations)
        expect(user_regs[soccer_event.id]).to eq(reg1)
        expect(user_regs[pizza_event.id]).to eq(reg2)
        expect(user_regs[study_event.id]).to be_nil
      end

      it "only loads registrations for the current user" do
        other_user = create(:user)
        create(:event_registration, user: other_user, event_post: soccer_event)
        user_reg = create(:event_registration, user: user, event_post: pizza_event)

        get :search

        user_regs = assigns(:user_registrations)
        expect(user_regs[soccer_event.id]).to be_nil
        expect(user_regs[pizza_event.id]).to eq(user_reg)
      end

      it "loads registrations even with search filters applied" do
        registration = create(:event_registration, user: user, event_post: soccer_event)

        get :search, params: {
          q: "soccer",
          category_id: sports_category.id
        }

        user_regs = assigns(:user_registrations)
        expect(user_regs[soccer_event.id]).to eq(registration)
      end
    end

    it "always orders results by event_time ascending" do
      get :search
      events = assigns(:event_posts)
      events.each_cons(2) do |earlier, later|
        expect(earlier.event_time).to be <= later.event_time
      end
    end
  end

  describe "GET #find" do
    it "returns http success" do
      get :find
      expect(response).to have_http_status(:success)
    end

    it "renders the find template" do
      get :find
      expect(response).to render_template(:find)
    end
  end

  describe "GET #show" do
    let(:event_post) { create(:event_post) }

    it "returns http success" do
      get :show, params: { id: event_post.id }
      expect(response).to have_http_status(:success)
    end

    it "renders the show template" do
      get :show, params: { id: event_post.id }
      expect(response).to render_template(:show)
    end

    it "assigns the requested event to @event_post" do
      get :show, params: { id: event_post.id }
      expect(assigns(:event_post)).to eq(event_post)
    end

    it "finds user's registration if they're registered" do
      user = login_user
      registration = create(:event_registration, user: user, event_post: event_post)

      get :show, params: { id: event_post.id }
      expect(assigns(:registration)).to eq(registration)
    end

    it "sets @registration to nil if user is not registered" do
      login_user

      get :show, params: { id: event_post.id }
      expect(assigns(:registration)).to be_nil
    end
  end

  describe "GET #new" do
    it "returns http success" do
      get :new
      expect(response).to have_http_status(:success)
    end

    it "renders the new template" do
      get :new
      expect(response).to render_template(:new)
    end

    it "assigns a new EventPost to @event_post" do
      get :new
      expect(assigns(:event_post)).to be_a_new(EventPost)
    end

    it "loads all event categories" do
      sports = create(:event_category, :sports)
      food = create(:event_category, :food)

      get :new
      expect(assigns(:event_categories)).to include(sports, food)
    end
  end

  describe "POST #create" do
    let(:valid_params) do
      {
        event_post: {
          name: "Test Event",
          description: "Test description",
          event_category_id: create(:event_category).id,
          event_time: 2.days.from_now,
          capacity: 20,
          location_name: "Test Location"
        }
      }
    end

    context "with valid parameters" do
      it "creates a new event post" do
        expect {
          post :create, params: valid_params
        }.to change(EventPost, :count).by(1)
      end

      it "assigns the event to the current user as organizer" do
        user = login_user
        post :create, params: valid_params

        expect(EventPost.last.organizer).to eq(user)
      end

      it "redirects to the event page" do
        post :create, params: valid_params
        expect(response).to redirect_to(event_post_path(EventPost.last))
      end

      it "sets a success notice" do
        post :create, params: valid_params
        expect(flash[:notice]).to eq("Event created successfully!")
      end
    end

    context "with invalid parameters" do
      let(:invalid_params) do
        {
          event_post: {
            name: "",
            capacity: -5,
            event_time: nil
          }
        }
      end

      it "does not create a new event post" do
        expect {
          post :create, params: invalid_params
        }.not_to change(EventPost, :count)
      end

      it "renders the new template" do
        post :create, params: invalid_params
        expect(response).to render_template(:new)
      end

      it "returns unprocessable entity status" do
        post :create, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "loads event categories for the form" do
        sports = create(:event_category, :sports)
        post :create, params: invalid_params

        expect(assigns(:event_categories)).to include(sports)
      end
    end

    context "when not logged in" do
      before do
        session.delete(:user_id)
      end

      it "redirects to login page" do
        post :create, params: valid_params
        expect(response).to redirect_to(login_path)
      end

      it "does not create an event" do
        expect {
          post :create, params: valid_params
        }.not_to change(EventPost, :count)
      end
    end
  end
end
