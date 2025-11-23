require 'rails_helper'

RSpec.describe UsersController, type: :controller do
  # Note: Registration is now handled by Devise (Users::RegistrationsController)
  # This controller only handles user profile display and search

  describe "GET #show" do
    let(:user) { create(:user) }
    let!(:organized_event) { create(:event_post, organizer: user) }
    let!(:attended_event) { create(:event_post) }

    before do
      create(:event_registration, user: user, event_post: attended_event)
    end

    it "assigns the requested user to @user" do
      get :show, params: { id: user.id }
      expect(assigns(:user)).to eq(user)
    end

    it "assigns organized events" do
      get :show, params: { id: user.id }
      expect(assigns(:organized_events)).to include(organized_event)
    end

    it "assigns attended events" do
      get :show, params: { id: user.id }
      expect(assigns(:attended_events)).to include(attended_event)
    end
  end

  describe "GET #search" do
    let!(:user1) { create(:user, name: "Alice Smith") }
    let!(:user2) { create(:user, name: "Bob Johnson") }
    let!(:user3) { create(:user, name: "Alice Johnson") }

    it "finds users matching the query" do
      get :search, params: { q: "Alice" }
      expect(assigns(:users)).to include(user1, user3)
      expect(assigns(:users)).not_to include(user2)
    end

    it "performs case-insensitive search" do
      get :search, params: { q: "alice" }
      expect(assigns(:users)).to include(user1, user3)
    end

    it "returns empty array when query is blank" do
      get :search, params: { q: "" }
      expect(assigns(:users)).to be_empty
    end

    it "limits results to 10 users" do
      15.times { create(:user, name: "Test User") }
      get :search, params: { q: "Test" }
      expect(assigns(:users).count).to be <= 10
    end
  end
end
