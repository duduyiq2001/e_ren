require 'rails_helper'

RSpec.describe Users::SessionsController, type: :controller do
  before(:each) do
    @request.env["devise.mapping"] = Devise.mappings[:user]
  end

  describe "POST #create" do
    let(:user) { create(:user, :confirmed, email: "test@wustl.edu", password: "password123") }

    context "when user exists with valid credentials" do
      it "signs in the user" do
        post :create, params: { user: { email: user.email, password: "password123" } }
        expect(response).to redirect_to(root_path)
        expect(controller.current_user).to eq(user)
      end
    end

    context "when user does not exist" do
      it "shows 'User not found' message" do
        post :create, params: { user: { email: "nonexistent@wustl.edu", password: "password123" } }
        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to eq("User not found")
        expect(controller.current_user).to be_nil
      end
    end

    context "when user exists but password is invalid" do
      it "does not sign in the user" do
        post :create, params: { user: { email: user.email, password: "wrong_password" } }
        # Devise returns 200 with error message or 422, both are acceptable
        expect(response).to have_http_status(:ok).or have_http_status(:unprocessable_content)
        expect(controller.current_user).to be_nil
      end
    end

    context "when email is missing" do
      it "handles missing email gracefully" do
        post :create, params: { user: { password: "password123" } }
        # Should handle gracefully without error
        expect(response).to have_http_status(:ok).or have_http_status(:unprocessable_content)
      end
    end
  end
end

