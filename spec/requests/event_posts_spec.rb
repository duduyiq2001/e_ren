require 'rails_helper'
require 'pry-byebug'
RSpec.describe 'EventPosts', type: :request do
  let(:user) { create(:user) }

  before do
    sign_in_as(user)
  end

  describe 'GET /event_posts/' do
    let!(:sports_category) { create(:event_category, :sports) }
    let!(:food_category) { create(:event_category, :food) }
    let!(:event1) { create(:event_post, :today, event_category: sports_category) }
    let!(:event2) { create(:event_post, :tomorrow, event_category: food_category) }
    let!(:event3) { create(:event_post, :this_week, :with_attendees, event_category: sports_category) }

    it 'returns http success' do
      get '/event_posts/'
      expect(response).to have_http_status(:success)
              end

    it 'loads all event posts' do
      get '/event_posts/'
      # binding.pry
      expect(assigns(:event_posts)).to match_array([event1, event2, event3])
    end

    it 'orders events by event_time' do
      get '/event_posts/'
      events = assigns(:event_posts)
      expect(events.first.event_time).to be <= events.last.event_time
    end
  end

  describe 'GET /event_posts/search' do
    let!(:sports_category) { create(:event_category, :sports) }
    let!(:food_category) { create(:event_category, :food) }
    let!(:academic_category) { create(:event_category, :academic) }

    let!(:soccer_event) do
      create(:event_post,
             name: 'Soccer Tournament',
             event_category: sports_category,
             event_time: 2.days.from_now,
             latitude: 37.7749,
             longitude: -122.4194)
    end

    let!(:pizza_event) do
      create(:event_post,
             name: 'Pizza Party',
             event_category: food_category,
             event_time: 1.day.from_now.change(hour: 18),
             latitude: 37.7750,
             longitude: -122.4195)
    end

    let!(:study_event) do
      create(:event_post,
             name: 'Study Session',
             event_category: academic_category,
             event_time: 5.days.from_now,
             latitude: 40.7128,
             longitude: -74.0060)
    end

    context 'without any filters' do
      it 'returns http success' do
        get '/event_posts/search'
        expect(response).to have_http_status(:success)
      end

      it 'shows upcoming events by default' do
        get '/event_posts/search'
        events = assigns(:event_posts)
        expect(events).to include(soccer_event, pizza_event, study_event)
      end

      it 'loads event categories for dropdown' do
        get '/event_posts/search'
        expect(assigns(:event_categories)).to include(sports_category, food_category, academic_category)
      end
    end

    context 'with name search' do
      it 'finds events by fuzzy name match' do
        get '/event_posts/search', params: { q: 'soccer' }
        events = assigns(:event_posts)
        expect(events).to include(soccer_event)
        expect(events).not_to include(pizza_event, study_event)
      end

      it 'is case insensitive' do
        get '/event_posts/search', params: { q: 'PIZZA' }
        events = assigns(:event_posts)
        expect(events).to include(pizza_event)
      end

      it 'matches partial names' do
        get '/event_posts/search', params: { q: 'pizz' }
        events = assigns(:event_posts)
        expect(events).to include(pizza_event)
      end

      it 'returns empty when no matches found' do
        get '/event_posts/search', params: { q: 'Nonexistent Event' }
        events = assigns(:event_posts)
        expect(events).to be_empty
      end
    end

    context 'with category filter' do
      it 'filters events by category' do
        get '/event_posts/search', params: { category_id: sports_category.id }
        events = assigns(:event_posts)
        expect(events).to include(soccer_event)
        expect(events).not_to include(pizza_event, study_event)
      end

      it 'shows all events when no category specified' do
        get '/event_posts/search'
        events = assigns(:event_posts)
        expect(events.count).to eq(3)
      end
    end

    context 'with time filters' do
      before do
        # Mock Geocoder to avoid actual API calls
        Geocoder::Lookup::Test.set_default_stub(
          [{ 'latitude' => 37.7749, 'longitude' => -122.4194 }]
        )

        # Create events at specific times
        @tomorrow_event = create(:event_post, event_category: sports_category,
                                              event_time: 1.day.from_now.change(hour: 14))
        @two_days_event = create(:event_post, :two_days_from_now, event_category: sports_category)
        @next_week_event = create(:event_post, :next_week, event_category: sports_category)
      end

      after do
        Geocoder::Lookup::Test.reset
      end

      it 'filters events for tomorrow using custom date range' do
        tomorrow = 1.day.from_now.to_date
        get '/event_posts/search', params: { start_date: tomorrow, end_date: tomorrow }
        events = assigns(:event_posts)
        expect(events).to include(@tomorrow_event, pizza_event)
        expect(events).not_to include(@two_days_event, @next_week_event)
      end

      
      it 'filters events by custom date range' do
        start_date = Date.today
        end_date = 3.days.from_now.to_date

        get '/event_posts/search', params: {
          start_date: start_date,
          end_date: end_date
        }

        events = assigns(:event_posts)
        expect(events).to include(soccer_event, pizza_event)
        expect(events).not_to include(study_event)
      end
    end

    context 'with location filter' do
      before do
        # Mock Geocoder to avoid actual API calls
        allow(EventPost).to receive(:near).and_return(EventPost.all)
      end

      it 'filters events by proximity when lat/lng provided' do
        # Mock near scope to return only nearby events
        nearby_scope = double('ActiveRecord::Relation')
        allow(nearby_scope).to receive(:where).and_return(nearby_scope)
        allow(nearby_scope).to receive(:order).and_return([soccer_event, pizza_event])
        allow(EventPost).to receive(:includes).and_return(EventPost.all)
        allow(EventPost.all).to receive(:near_location).with('37.7749', '-122.4194', '10').and_return(nearby_scope)

        get '/event_posts/search', params: {
          latitude: '37.7749',
          longitude: '-122.4194',
          radius: '10'
        }

        expect(response).to have_http_status(:success)
      end

      it 'uses default radius of 10 miles when not specified' do
        get '/event_posts/search', params: {
          latitude: '37.7749',
          longitude: '-122.4194'
        }

        expect(response).to have_http_status(:success)
      end

      it 'accepts custom radius' do
        get '/event_posts/search', params: {
          latitude: '37.7749',
          longitude: '-122.4194',
          radius: '25'
        }

        expect(response).to have_http_status(:success)
      end
    end

    context 'with combined filters' do
      it 'applies multiple filters together' do
        get '/event_posts/search', params: {
          q: 'Soccer',
          category_id: sports_category.id,
          time_filter: 'upcoming'
        }

        events = assigns(:event_posts)
        expect(events).to include(soccer_event)
        expect(events).not_to include(pizza_event, study_event)
      end

      it 'chains all filters correctly' do
        tomorrow_sports = create(:event_post,
                                 name: 'Basketball Game',
                                 event_category: sports_category,
                                 event_time: 1.day.from_now.change(hour: 20))

        get '/event_posts/search', params: {
          q: 'ball',
          category_id: sports_category.id,
          time_filter: 'upcoming'
        }

        events = assigns(:event_posts)
        expect(events).to include(tomorrow_sports)
        expect(events).not_to include(study_event)
      end
    end

      end

  describe 'GET /event_posts/find' do
    it 'returns http success' do
      get '/event_posts/find'
      expect(response).to have_http_status(:success)
    end
  end

  describe 'POST /event_posts' do
    let!(:category) { create(:event_category) }

    let(:valid_params) do
      {
        event_post: {
          name: "Test Event",
          description: "A test event description",
          event_time: 2.days.from_now,
          capacity: 50,
          event_category_id: category.id,
          location_name: "Washington University",
          latitude: 38.6488,
          longitude: -90.3108
        }
      }
    end

    it 'creates a new event post' do
      expect {
        post '/event_posts', params: valid_params
      }.to change(EventPost, :count).by(1)
    end

    it 'redirects to the created event' do
      post '/event_posts', params: valid_params
      expect(response).to redirect_to(event_post_path(EventPost.last))
    end

    it 'assigns the current user as organizer' do
      post '/event_posts', params: valid_params
      expect(EventPost.last.organizer).to eq(user)
    end
  end

  describe 'GET /event_posts/new' do
    it 'returns http success' do
      get '/event_posts/new'
      expect(response).to have_http_status(:success)
    end

    it 'assigns a new event_post' do
      get '/event_posts/new'
      expect(assigns(:event_post)).to be_a_new(EventPost)
    end
  end

  describe 'GET /event_posts/:id' do
    let!(:event_post) { create(:event_post) }

    it 'returns http success' do
      get "/event_posts/#{event_post.id}"
      expect(response).to have_http_status(:success)
    end

    it 'assigns the requested event_post' do
      get "/event_posts/#{event_post.id}"
      expect(assigns(:event_post)).to eq(event_post)
    end
  end

  describe 'GET /event_posts/:id/edit' do
    let!(:event_post) { create(:event_post, organizer: user) }

    it 'returns http success' do
      get "/event_posts/#{event_post.id}/edit"
      expect(response).to have_http_status(:success)
    end

    it 'assigns the requested event_post' do
      get "/event_posts/#{event_post.id}/edit"
      expect(assigns(:event_post)).to eq(event_post)
    end
  end

  describe 'PATCH /event_posts/:id' do
    let!(:event_post) { create(:event_post, organizer: user) }

    let(:update_params) do
      {
        event_post: {
          name: "Updated Event Name",
          capacity: 100
        }
      }
    end

    it 'updates the event post' do
      patch "/event_posts/#{event_post.id}", params: update_params
      event_post.reload
      expect(event_post.name).to eq("Updated Event Name")
      expect(event_post.capacity).to eq(100)
    end

    it 'redirects to the event post' do
      patch "/event_posts/#{event_post.id}", params: update_params
      expect(response).to redirect_to(event_post_path(event_post))
    end

    context 'when user is not the organizer' do
      let!(:other_user_event) { create(:event_post) }

      it 'does not allow update' do
        patch "/event_posts/#{other_user_event.id}", params: update_params
        expect(response).to redirect_to(event_post_path(other_user_event))
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe 'DELETE /event_posts/:id' do
    let!(:event_post) { create(:event_post, organizer: user) }

    it 'destroys the event post' do
      expect {
        delete "/event_posts/#{event_post.id}"
      }.to change(EventPost, :count).by(-1)
    end

    it 'redirects to event posts index' do
      delete "/event_posts/#{event_post.id}"
      expect(response).to redirect_to(event_posts_path)
    end

    context 'when user is not the organizer' do
      let!(:other_user_event) { create(:event_post) }

      it 'does not allow deletion' do
        expect {
          delete "/event_posts/#{other_user_event.id}"
        }.not_to change(EventPost, :count)
      end
    end
  end

  describe 'GET /event_posts/:id/registrations' do
    let!(:event_post) { create(:event_post, organizer: user) }
    let!(:registration1) { create(:event_registration, event_post: event_post) }
    let!(:registration2) { create(:event_registration, event_post: event_post) }

    it 'returns http success' do
      get "/event_posts/#{event_post.id}/registrations"
      expect(response).to have_http_status(:success)
    end

    it 'lists all registrations for the event' do
      get "/event_posts/#{event_post.id}/registrations"
      expect(assigns(:registrations)).to include(registration1, registration2)
    end

    context 'when user is not the organizer' do
      let!(:other_user_event) { create(:event_post) }

      it 'restricts access' do
        get "/event_posts/#{other_user_event.id}/registrations"
        expect(response).to redirect_to(event_post_path(other_user_event))
        expect(flash[:alert]).to be_present
      end
    end
  end
end
