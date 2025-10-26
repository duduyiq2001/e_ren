require 'rails_helper'

RSpec.describe UsersController, type: :controller do
  describe "GET #new" do
    it "returns http success" do
      get :new
      expect(response).to have_http_status(:success)
    end

    it "renders the new template" do
      get :new
      expect(response).to render_template(:new)
    end

    it "assigns a new User to @user" do
      get :new
      expect(assigns(:user)).to be_a_new(User)
    end
  end

  describe "POST #create" do
    context "with valid parameters" do
      let(:valid_params) do
        {
          user: {
            name: "Test User",
            email: "test@university.edu",
            password: "password123",
            password_confirmation: "password123"
          }
        }
      end

      it "creates a new user" do
        expect {
          post :create, params: valid_params
        }.to change(User, :count).by(1)
      end

      it "logs in the new user" do
        post :create, params: valid_params
        expect(session[:user_id]).to eq(User.last.id)
      end

      it "redirects to root path" do
        post :create, params: valid_params
        expect(response).to redirect_to(root_path)
      end

      it "sets a welcome notice" do
        post :create, params: valid_params
        expect(flash[:notice]).to eq("Welcome to E-Ren! Your account has been created.")
      end
    end

    context "with invalid parameters" do
      let(:invalid_params) do
        {
          user: {
            name: "",
            email: "invalid-email",
            password: "short",
            password_confirmation: "different"
          }
        }
      end

      it "does not create a new user" do
        expect {
          post :create, params: invalid_params
        }.not_to change(User, :count)
      end

      it "does not log in the user" do
        post :create, params: invalid_params
        expect(session[:user_id]).to be_nil
      end

      it "renders the new template" do
        post :create, params: invalid_params
        expect(response).to render_template(:new)
      end

      it "returns unprocessable entity status" do
        post :create, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "with optional phone number" do
      let(:params_with_phone) do
        {
          user: {
            name: "Test User",
            email: "test@university.edu",
            password: "password123",
            password_confirmation: "password123",
            phone_number: "+1234567890"
          }
        }
      end

      it "creates user with phone number" do
        post :create, params: params_with_phone
        expect(User.last.phone_number).to eq("+1234567890")
      end
    end
  end

  describe "GET #show" do
    let(:user) { create(:user) }
    let!(:organized_event) { create(:event_post, organizer: user) }
    let!(:attended_event) { create(:event_post) }

    before do
      create(:event_registration, user: user, event_post: attended_event)
    end

    it "returns http success" do
      get :show, params: { id: user.id }
      expect(response).to have_http_status(:success)
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

    it "returns http success" do
      get :search, params: { q: "Alice" }
      expect(response).to have_http_status(:success)
    end

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
