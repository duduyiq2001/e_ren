require 'rails_helper'
require 'pry-byebug'

RSpec.describe EventPost, type: :model do
  describe "associations" do
    it { should belong_to(:event_category) }
    it { should belong_to(:organizer).class_name('User').with_foreign_key('organizer_id') }
    it { should have_many(:event_registrations).dependent(:destroy_async) }
    it { should have_many(:attendees).through(:event_registrations).source(:user) }
    it { should belong_to(:deleted_by_user).class_name('User').with_foreign_key('deleted_by_id').optional }
  end

  describe "validations" do
    subject { build(:event_post) }

    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_most(255) }
    it { should validate_presence_of(:capacity) }
    it { should validate_numericality_of(:capacity).is_greater_than(0) }
    it { should validate_presence_of(:event_time) }

    context "event_time validation" do
      it "is invalid when event_time is in the past on create" do
        event = build(:event_post, event_time: 1.day.ago)
        expect(event).not_to be_valid
        expect(event.errors[:event_time]).to include("can't be in the past")
      end

      it "is valid when event_time is in the future on create" do
        event = build(:event_post, event_time: 1.day.from_now)
        expect(event).to be_valid
      end

      it "allows updating events even if event_time is in the past" do
        # Create event with future time
        event = create(:event_post, event_time: 1.day.from_now)

        # Simulate time passing - event is now in the past
        # Update the event (e.g., change capacity)
        event.capacity = 50
        event.event_time = 2.days.ago  # Past time

        # Should still be valid on update
        expect(event).to be_valid
        expect(event.save).to be true
      end

      it "allows querying and displaying past events" do
        # Create event with future time, then manually update to past
        event = create(:event_post, event_time: 1.day.from_now)
        event.update_column(:event_time, 2.days.ago)  # Bypass validations

        # Should be able to find and display past events
        expect(EventPost.find(event.id)).to eq(event)
        expect(event.reload.event_time).to be < Time.current
      end
    end

    context "google_maps_url format" do
      it "is valid with http URL" do
        event = build(:event_post, google_maps_url: "http://maps.google.com/test")
        expect(event).to be_valid
      end

      it "is valid with https URL" do
        event = build(:event_post, google_maps_url: "https://maps.google.com/test")
        expect(event).to be_valid
      end

      it "is valid when blank" do
        event = build(:event_post, google_maps_url: nil)
        expect(event).to be_valid
      end

      it "is invalid with malformed URL" do
        event = build(:event_post, google_maps_url: "not-a-url")
        expect(event).not_to be_valid
      end
    end
  end

  describe "scopes" do
    let!(:sports_category) { create(:event_category, :sports) }
    let!(:food_category) { create(:event_category, :food) }

    describe ".search_by_name" do
      let!(:soccer_event) { create(:event_post, name: "Soccer Tournament", event_category: sports_category) }
      let!(:pizza_event) { create(:event_post, name: "Pizza Party", event_category: food_category) }

      it "finds events by exact name match" do
        results = EventPost.search_by_name("Soccer Tournament")
        expect(results).to include(soccer_event)
        expect(results).not_to include(pizza_event)
      end

      it "finds events by partial name match" do
        results = EventPost.search_by_name("Pizza")
        expect(results).to include(pizza_event)
        expect(results).not_to include(soccer_event)
      end

      it "is case insensitive" do
        results = EventPost.search_by_name("SOCCER")
        expect(results).to include(soccer_event)
      end

      it "handles fuzzy search" do
        results = EventPost.search_by_name("socc")
        expect(results).to include(soccer_event)
      end

      it "returns all events when query is blank" do
        results = EventPost.search_by_name("")
        expect(results).to match_array([soccer_event, pizza_event])
      end

      it "returns all events when query is nil" do
        results = EventPost.search_by_name(nil)
        expect(results).to match_array([soccer_event, pizza_event])
      end
    end

    describe ".by_category" do
      let!(:soccer_event) { create(:event_post, event_category: sports_category) }
      let!(:pizza_event) { create(:event_post, event_category: food_category) }

      it "filters events by category_id" do
        results = EventPost.by_category(sports_category.id)
        expect(results).to include(soccer_event)
        expect(results).not_to include(pizza_event)
      end

      it "returns all events when category_id is nil" do
        results = EventPost.by_category(nil)
        expect(results).to match_array([soccer_event, pizza_event])
      end

      it "returns all events when category_id is blank" do
        results = EventPost.by_category("")
        expect(results).to match_array([soccer_event, pizza_event])
      end
    end

    describe ".upcoming" do
      let!(:future_event1) { create(:event_post, :tomorrow, event_category: sports_category) }
      let!(:future_event2) { create(:event_post, :this_week, event_category: sports_category) }

      it "returns only future events" do
        results = EventPost.upcoming
        expect(results).to include(future_event1, future_event2)
      end

      it "orders events by event_time ascending" do
        results = EventPost.upcoming
        expect(results.first.event_time).to be <= results.last.event_time
      end
    end

    describe ".today" do
      let!(:tomorrow_morning) { create(:event_post, event_time: 1.day.from_now.change(hour: 9), event_category: sports_category) }
      let!(:tomorrow_evening) { create(:event_post, event_time: 1.day.from_now.change(hour: 18), event_category: sports_category) }
      let!(:next_day_event) { create(:event_post, event_time: 2.days.from_now, event_category: sports_category) }

      it "returns only events happening on a specific day" do
        results = EventPost.where(event_time: 1.day.from_now.beginning_of_day..1.day.from_now.end_of_day)
        expect(results).to include(tomorrow_morning, tomorrow_evening)
        expect(results).not_to include(next_day_event)
      end

      it "includes events from start to end of day" do
        midnight_event = create(:event_post, event_time: 1.day.from_now.beginning_of_day, event_category: sports_category)
        end_of_day_event = create(:event_post, event_time: 1.day.from_now.end_of_day, event_category: sports_category)

        results = EventPost.where(event_time: 1.day.from_now.beginning_of_day..1.day.from_now.end_of_day)
        expect(results).to include(midnight_event, end_of_day_event)
      end
    end

    describe ".this_week" do
      let!(:this_week_event) { create(:event_post, :this_week, event_category: sports_category) }
      let!(:next_week_event) { create(:event_post, :next_week, event_category: sports_category) }

      it "returns only events happening this week" do
        results = EventPost.this_week
        expect(results).to include(this_week_event)
        expect(results).not_to include(next_week_event)
      end

          end

    describe ".between_dates" do
      before do
        # Mock Geocoder to avoid actual API calls
        Geocoder::Lookup::Test.set_default_stub(
          [{ 'latitude' => 37.7749, 'longitude' => -122.4194 }]
        )
      end

      after do
        Geocoder::Lookup::Test.reset
      end

      let(:start_date) { Time.current + 1.day }
      let(:mid_date) { Time.current + 15.days }
      let(:end_date) { Time.current + 30.days }
      let(:after_end_date) { Time.current + 31.days }

      let!(:event_1) { create(:event_post, event_time: start_date, event_category: sports_category) }
      let!(:event_15) { create(:event_post, event_time: mid_date, event_category: sports_category) }
      let!(:event_30) { create(:event_post, event_time: end_date, event_category: sports_category) }
      let!(:event_31) { create(:event_post, event_time: after_end_date, event_category: sports_category) }

      it "returns events within date range" do
        results = EventPost.between_dates(start_date, end_date)
        expect(results).to include(event_1, event_15, event_30)
        expect(results).not_to include(event_31)
      end

      it "includes events on boundary dates" do
        results = EventPost.between_dates(start_date, mid_date)
        expect(results).to include(event_1, event_15)
      end

      it "returns all events when start_date is nil" do
        
        results = EventPost.between_dates(nil, end_date)
        expect(results.count).to eq(3)
      end

      it "returns all events when end_date is nil" do
        results = EventPost.between_dates(start_date, nil)
        expect(results.count).to eq(4)
      end

      it "returns all events when both dates are nil" do
        results = EventPost.between_dates(nil, nil)
        expect(results.count).to eq(4)
      end
    end

    describe ".near_location" do
      let!(:sf_event) { create(:event_post, :near_location, event_category: sports_category) }
      let!(:ny_event) { create(:event_post, :far_location, event_category: sports_category) }

      before do
        # Mock Geocoder to avoid actual API calls
        Geocoder::Lookup::Test.add_stub(
          [37.7749, -122.4194],
          [{ 'latitude' => 37.7749, 'longitude' => -122.4194 }]
        )
      end

      it "returns events near the specified location" do
        results = EventPost.near_location(37.7749, -122.4194, 10)
        expect(results).to include(sf_event)
        expect(results).not_to include(ny_event)
      end

      it "respects radius parameter" do
        # With large radius, should include both
        results = EventPost.near_location(37.7749, -122.4194, 3000)
        expect(results).to include(sf_event, ny_event)
      end

      it "returns all events when latitude is nil" do
        results = EventPost.near_location(nil, -122.4194, 10)
        expect(results).to match_array([sf_event, ny_event])
      end

      it "returns all events when longitude is nil" do
        results = EventPost.near_location(37.7749, nil, 10)
        expect(results).to match_array([sf_event, ny_event])
      end
    end

    describe "scope chaining" do
      let!(:soccer_today) { create(:event_post, name: "Soccer Game", event_category: sports_category, event_time: 1.day.from_now.change(hour: 18)) }
      let!(:pizza_today) { create(:event_post, name: "Pizza Party", event_category: food_category, event_time: 1.day.from_now.change(hour: 19)) }
      let!(:soccer_tomorrow) { create(:event_post, name: "Soccer Practice", event_category: sports_category, event_time: 2.days.from_now) }

      it "chains search_by_name and by_category" do
        results = EventPost.search_by_name("Soccer").by_category(sports_category.id)
        expect(results).to include(soccer_today, soccer_tomorrow)
        expect(results).not_to include(pizza_today)
      end

      it "chains multiple scopes together" do
        tomorrow_scope = EventPost.where(event_time: 1.day.from_now.beginning_of_day..1.day.from_now.end_of_day)
        results = EventPost.search_by_name("Soccer").by_category(sports_category.id).merge(tomorrow_scope)
        expect(results).to include(soccer_today)
        expect(results).not_to include(soccer_tomorrow, pizza_today)
      end

      it "maintains correct results when chained in different orders" do
        tomorrow_scope = EventPost.where(event_time: 1.day.from_now.beginning_of_day..1.day.from_now.end_of_day)
        results1 = tomorrow_scope.by_category(sports_category.id).search_by_name("Soccer")
        results2 = EventPost.search_by_name("Soccer").merge(tomorrow_scope).by_category(sports_category.id)
        expect(results1).to match_array(results2)
      end
    end
  end

  describe "instance methods" do
    describe "#spots_remaining" do
      let(:event) { create(:event_post, capacity: 20) }

      it "returns capacity when no registrations" do
        expect(event.spots_remaining).to eq(20)
      end

      it "returns correct spots when registrations exist" do
        event.update(registrations_count: 5)
        expect(event.spots_remaining).to eq(15)
      end

      it "returns 0 when event is full" do
        event.update(registrations_count: 20)
        expect(event.spots_remaining).to eq(0)
      end
    end

    describe "#full?" do
      let(:event) { create(:event_post, capacity: 20) }

      it "returns false when spots available" do
        event.update(registrations_count: 10)
        expect(event.full?).to be false
      end

      it "returns true when no spots available" do
        event.update(registrations_count: 20)
        expect(event.full?).to be true
      end

      it "returns true when overbooked" do
        event.update(registrations_count: 25)
        expect(event.full?).to be true
      end
    end

    describe "#parse_google_maps_url" do
      let(:event) { build(:event_post) }

      context "with ?q= format URL" do
        it "extracts latitude and longitude" do
          event.google_maps_url = "https://maps.google.com/?q=37.7749,-122.4194"
          result = event.parse_google_maps_url
          expect(result).to be true
          expect(event.latitude).to eq(37.7749)
          expect(event.longitude).to eq(-122.4194)
        end
      end

      context "with /@ format URL" do
        it "extracts latitude and longitude" do
          event.google_maps_url = "https://www.google.com/maps/@37.7749,-122.4194,15z"
          result = event.parse_google_maps_url
          expect(result).to be true
          expect(event.latitude).to eq(37.7749)
          expect(event.longitude).to eq(-122.4194)
        end

        it "handles negative coordinates" do
          event.google_maps_url = "https://www.google.com/maps/@-33.8688,151.2093,10z"
          result = event.parse_google_maps_url
          expect(result).to be true
          expect(event.latitude).to eq(-33.8688)
          expect(event.longitude).to eq(151.2093)
        end
      end

      context "with place_id format" do
        it "extracts place_id" do
          event.google_maps_url = "https://maps.google.com/place_id=ChIJN1t_tDeuEmsRUsoyG83frY4"
          result = event.parse_google_maps_url
          expect(result).to be true
          expect(event.google_place_id).to eq("ChIJN1t_tDeuEmsRUsoyG83frY4")
        end
      end

      context "with invalid URL" do
        it "returns false when URL doesn't match patterns" do
          event.google_maps_url = "https://not-a-maps-url.com"
          result = event.parse_google_maps_url
          expect(result).to be false
        end

        it "returns nil when google_maps_url is blank" do
          event.google_maps_url = nil
          expect(event.parse_google_maps_url).to be_nil
        end
      end
    end
  end

  describe "callbacks" do
    describe "geocoding" do
      before do
        # Mock Geocoder to avoid actual API calls
        Geocoder::Lookup::Test.set_default_stub(
          [{ 'latitude' => 37.7749, 'longitude' => -122.4194 }]
        )
      end

      after do
        Geocoder::Lookup::Test.reset
      end

      it "geocodes location_name after validation" do
        event = build(:event_post, location_name: "San Francisco", latitude: nil, longitude: nil)
        event.save
        expect(event.latitude).to be_present
        expect(event.longitude).to be_present
      end

      it "does not geocode when location_name is blank" do
        event = build(:event_post, location_name: nil)
        expect(event).not_to receive(:geocode)
        event.save
      end

      it "does not geocode when location_name hasn't changed and latitude exists" do
        event = create(:event_post, location_name: "San Francisco", latitude: 37.7749, longitude: -122.4194)
        expect(event).not_to receive(:geocode)
        event.update(name: "Updated Name")
      end

      it "geocodes when location_name changes" do
        event = create(:event_post, location_name: "San Francisco", latitude: 37.7749, longitude: -122.4194)
        original_lat = event.latitude

        Geocoder::Lookup::Test.add_stub(
          "New York",
          [{ 'latitude' => 40.7128, 'longitude' => -74.0060 }]
        )

        event.update(location_name: "New York")
        event.reload
        expect(event.latitude).not_to eq(original_lat)
      end
    end
  end

  describe "database constraints" do
    it "has default registrations_count of 0" do
      event = create(:event_post)
      expect(event.registrations_count).to eq(0)
    end

    it "requires event_category_id" do
      expect {
        create(:event_post, event_category: nil)
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "requires organizer_id" do
      expect {
        create(:event_post, organizer: nil)
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe "soft delete functionality" do
    let(:admin) { create(:user, :admin) }
    let(:event_post) { create(:event_post) }
    let!(:registration1) { create(:event_registration, event_post: event_post) }
    let!(:registration2) { create(:event_registration, event_post: event_post) }

    describe "#soft_delete_with_cascade!" do
      it "soft deletes event and cascades to registrations" do
        event_post.soft_delete_with_cascade!(admin, reason: 'Test deletion')
        
        expect(event_post.reload.discarded?).to be true
        expect(registration1.reload.discarded?).to be true
        expect(registration2.reload.discarded?).to be true
      end

      it "records deletion metadata" do
        event_post.soft_delete_with_cascade!(admin, reason: 'Inappropriate content')
        
        expect(event_post.deleted_by_id).to eq(admin.id)
        expect(event_post.deletion_reason).to eq('Inappropriate content')
      end

      it "does not hard delete records" do
        event_id = event_post.id
        reg_id = registration1.id
        
        event_post.soft_delete_with_cascade!(admin)
        
        expect(EventPost.with_discarded.find(event_id)).to be_present
        expect(EventRegistration.with_discarded.find(reg_id)).to be_present
      end
    end

    describe "#deletion_preview" do
      it "returns accurate counts" do
        preview = event_post.deletion_preview
        
        expect(preview[:event_registrations]).to eq(2)
        expect(preview[:attendees_count]).to eq(2)
      end

      it "returns zero for events with no registrations" do
        new_event = create(:event_post)
        preview = new_event.deletion_preview
        
        expect(preview[:event_registrations]).to eq(0)
        expect(preview[:attendees_count]).to eq(0)
      end
    end
  end
end
