require 'rails_helper'

RSpec.describe "Devise Authentication", type: :request do
  describe "User Registration" do
    context "with valid parameters" do
      let(:valid_params) do
        {
          user: {
            name: "New User",
            email: "newuser@wustl.edu",
            password: "password123",
            password_confirmation: "password123"
          }
        }
      end

      it "creates a new user" do
        expect {
          post user_registration_path, params: valid_params
        }.to change(User, :count).by(1)
      end

      it "redirects to root path after registration" do
        post user_registration_path, params: valid_params
        expect(response).to redirect_to(root_path)
      end

      it "signs in the user after registration" do
        post user_registration_path, params: valid_params
        follow_redirect!
        # Check that user is signed in by verifying they can access protected pages
        get event_posts_path
        expect(response).to have_http_status(:success)
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

      it "does not create a user" do
        expect {
          post user_registration_path, params: invalid_params
        }.not_to change(User, :count)
      end

      it "renders the registration form with errors" do
        post user_registration_path, params: invalid_params
        # Devise may return 200 with error messages or 422, both are acceptable
        expect(response).to have_http_status(:ok).or have_http_status(:unprocessable_content)
        expect(response.body).to match(/error|invalid/i)
      end
    end
  end

  describe "User Sign In" do
    let(:user) { create(:user, email: "test@wustl.edu", password: "password123") }

    context "with valid credentials" do
      it "signs in the user" do
        post user_session_path, params: { user: { email: user.email, password: "password123" } }
        expect(response).to redirect_to(root_path)
      end

      it "allows access to protected pages after sign in" do
        post user_session_path, params: { user: { email: user.email, password: "password123" } }
        follow_redirect!
        get event_posts_path
        expect(response).to have_http_status(:success)
      end
    end

    context "when user does not exist" do
      it "shows a generic error message" do
        post user_session_path, params: { user: { email: "nonexistent@wustl.edu", password: "password123" } }
        expect(response).to redirect_to(new_user_session_path)
        follow_redirect!
        expect(response.body).to match(/Invalid|error/i)
      end

      it "does not sign in any user" do
        post user_session_path, params: { user: { email: "nonexistent@wustl.edu", password: "password123" } }
        get event_posts_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "with invalid password" do
      it "does not sign in the user" do
        post user_session_path, params: { user: { email: user.email, password: "wrong_password" } }
        # Devise may return 200 with error message or 422, both are acceptable
        expect(response).to have_http_status(:ok).or have_http_status(:unprocessable_content)
        # Verify user is not signed in
        get event_posts_path
        expect(response).to redirect_to(new_user_session_path)
      end

      it "shows error message" do
        post user_session_path, params: { user: { email: user.email, password: "wrong_password" } }
        expect(response.body).to match(/Invalid|error/i)
      end
    end
  end

  describe "User Sign Out" do
    let(:user) { create(:user) }

    before do
      sign_in user
    end

    it "signs out the user" do
      delete destroy_user_session_path
      expect(response).to redirect_to(root_path)
    end

    it "prevents access to protected pages after sign out" do
      delete destroy_user_session_path
      get event_posts_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "Protected Routes" do
    context "when user is not signed in" do
      it "redirects to sign in page" do
        get event_posts_path
        expect(response).to redirect_to(new_user_session_path)
      end

      it "allows access after sign in" do
        user = create(:user)
        get new_user_session_path
        post user_session_path, params: { user: { email: user.email, password: "password123" } }
        follow_redirect!
        get event_posts_path
        expect(response).to have_http_status(:success)
      end
    end

    context "when user is signed in" do
      let(:user) { create(:user) }

      before do
        sign_in user
      end

      it "allows access to protected pages" do
        get event_posts_path
        expect(response).to have_http_status(:success)
      end

      it "allows access to user profile" do
        get user_path(user)
        expect(response).to have_http_status(:success)
      end
    end
  end
end

