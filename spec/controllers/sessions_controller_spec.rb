require 'rails_helper'

RSpec.describe SessionsController, type: :controller do
  describe "GET #new" do
    it "returns http success" do
      get :new
      expect(response).to have_http_status(:success)
    end

    it "renders the new template" do
      get :new
      expect(response).to render_template(:new)
    end
  end

  describe "POST #create" do
    let(:user) { create(:user, email: "test@example.com", password: "password123") }

    context "with valid credentials" do
      it "logs in the user" do
        post :create, params: { email: user.email, password: "password123" }
        expect(session[:user_id]).to eq(user.id)
      end

      it "redirects to root path" do
        post :create, params: { email: user.email, password: "password123" }
        expect(response).to redirect_to(root_path)
      end

      it "sets a success notice" do
        post :create, params: { email: user.email, password: "password123" }
        expect(flash[:notice]).to eq("Logged in successfully!")
      end
    end

    context "with invalid email" do
      it "does not log in the user" do
        post :create, params: { email: "wrong@example.com", password: "password123" }
        expect(session[:user_id]).to be_nil
      end

      it "renders the new template" do
        post :create, params: { email: "wrong@example.com", password: "password123" }
        expect(response).to render_template(:new)
      end

      it "sets an error flash message" do
        post :create, params: { email: "wrong@example.com", password: "password123" }
        expect(flash[:alert]).to eq("Invalid email or password")
      end

      it "returns unprocessable entity status" do
        post :create, params: { email: "wrong@example.com", password: "password123" }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "with invalid password" do
      it "does not log in the user" do
        post :create, params: { email: user.email, password: "wrong_password" }
        expect(session[:user_id]).to be_nil
      end

      it "renders the new template" do
        post :create, params: { email: user.email, password: "wrong_password" }
        expect(response).to render_template(:new)
      end

      it "sets an error flash message" do
        post :create, params: { email: user.email, password: "wrong_password" }
        expect(flash[:alert]).to eq("Invalid email or password")
      end
    end
  end

  describe "DELETE #destroy" do
    let(:user) { create(:user) }

    before do
      session[:user_id] = user.id
    end

    it "logs out the user" do
      delete :destroy
      expect(session[:user_id]).to be_nil
    end

    it "redirects to root path" do
      delete :destroy
      expect(response).to redirect_to(root_path)
    end

    it "sets a success notice" do
      delete :destroy
      expect(flash[:notice]).to eq("Logged out successfully!")
    end
  end
end
