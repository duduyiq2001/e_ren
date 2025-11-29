require 'rails_helper'
require 'pry-byebug'

RSpec.describe "event_posts/registrations.html.erb", type: :view do
  let(:organizer) { create(:user, name: "Event Organizer") }
  let(:category) { create(:event_category) }
  let(:event_post) do
    create(:event_post,
      name: "Test Event",
      organizer: organizer,
      capacity: 20,
      event_category: category,
      event_time: 2.days.from_now
    )
  end

  let!(:confirmed_user1) { create(:user, name: "John Confirmed") }
  let!(:confirmed_user2) { create(:user, name: "Jane Confirmed") }
  let!(:waitlisted_user) { create(:user, name: "Bob Waitlisted") }

  let!(:confirmed_reg1) do
    create(:event_registration,
      user: confirmed_user1,
      event_post: event_post,
      status: :confirmed,
      attendance_confirmed: false
    )
  end

  let!(:confirmed_reg2) do
    create(:event_registration,
      user: confirmed_user2,
      event_post: event_post,
      status: :confirmed,
      attendance_confirmed: false
    )
  end

  let!(:waitlisted_reg) do
    create(:event_registration,
      user: waitlisted_user,
      event_post: event_post,
      status: :waitlisted,
      attendance_confirmed: false
    )
  end

  before do
    assign(:event_post, event_post)
    assign(:registrations, [confirmed_reg1, confirmed_reg2, waitlisted_reg])
    assign(:confirmed_registrations, [confirmed_reg1, confirmed_reg2])
    assign(:waitlisted_registrations, [waitlisted_reg])
  end

  describe "page header" do
    before { render }

    it "displays event name" do
      expect(rendered).to have_content("Test Event")
    end

    it "displays page title" do
      expect(rendered).to have_content("Event Registrations")
    end

    it "shows back to event link" do
      expect(rendered).to have_link("Back to Event", href: event_post_path(event_post))
    end
  end

  describe "summary stats" do
    before { render }

    it "displays total capacity" do
      expect(rendered).to have_content("Capacity")
      expect(rendered).to have_content("20")
    end

    it "displays confirmed count" do
      expect(rendered).to have_content("Confirmed")
      expect(rendered).to have_content("2")
    end

    it "displays waitlisted count" do
      expect(rendered).to have_content("Waitlisted")
      expect(rendered).to have_content("1")
    end
  end

  describe "registration lists" do
    before { render }

    it "displays confirmed user names" do
      expect(rendered).to have_content("John Confirmed")
      expect(rendered).to have_content("Jane Confirmed")
    end

    it "displays waitlisted user names" do
      expect(rendered).to have_content("Bob Waitlisted")
    end
  end

  describe "event status banner" do
    context "for future event" do
      before { render }

      it "shows future event message" do
        expect(rendered).to have_content("Event scheduled:")
      end

      it "does not show past event message" do
        expect(rendered).not_to have_content("Event has ended")
      end
    end

    context "for past event" do
      let(:past_event) do
        create(:event_post,
          name: "Past Event",
          organizer: organizer,
          capacity: 20,
          event_category: category
        ).tap { |e| e.update_column(:event_time, 2.hours.ago) }
      end

      before do
        assign(:event_post, past_event)
        assign(:registrations, [])
        assign(:confirmed_registrations, [])
        assign(:waitlisted_registrations, [])
        render
      end

      it "shows past event message" do
        expect(rendered).to have_content("Event Complete")
        expect(rendered).to have_content("Confirm attendance to award E-points")
      end

      it "does not show future event message" do
        expect(rendered).not_to have_content("Event scheduled:")
      end
    end
  end
end
