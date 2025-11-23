require 'rails_helper'
require 'pry-byebug'
RSpec.describe Users::RegistrationsController, type: :controller do
  describe "POST #create" do
    context "with valid parameters" do
      let(:valid_params) do
        {
          user: {
            name: "New User",
            email: "newuser@wustl.edu",
            password: "password123",
            password_confirmation: "password123",
            phone_number: "555-123-4567"
          }
        }
      end

      it "creates a new user" do
        expect {
          post :create, params: valid_params
        }.to change(User, :count).by(1)
      end

      it "sends confirmation email" do
        # Unmock send_confirmation_instructions for this test
        allow_any_instance_of(User).to receive(:send_confirmation_instructions).and_call_original

        expect {
          post :create, params: valid_params
        }.to change { ActionMailer::Base.deliveries.count }.by(1)
      end

      it "does not sign in the user before email confirmation" do
        post :create, params: valid_params
        expect(controller.current_user).to be_nil
      end

      it "permits custom parameters (name, phone_number)" do
        post :create, params: valid_params
        user = User.find_by(email: "newuser@wustl.edu")
        expect(user.name).to eq("New User")
        expect(user.phone_number).to eq("555-123-4567")
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
          post :create, params: invalid_params
        }.not_to change(User, :count)
      end

      it "renders the registration form with errors" do
        post :create, params: invalid_params
        expect(assigns(:user).errors).not_to be_empty
      end
    end

    context "with duplicate email" do
      let!(:existing_user) { create(:user, email: "existing@wustl.edu") }
      let(:duplicate_params) do
        {
          user: {
            name: "Another User",
            email: "existing@wustl.edu",
            password: "password123",
            password_confirmation: "password123"
          }
        }
      end

      it "does not create a duplicate user" do
        expect {
          post :create, params: duplicate_params
        }.not_to change(User, :count)
      end

      it "shows validation error" do
        post :create, params: duplicate_params
        expect(assigns(:user).errors[:email]).to be_present
      end
    end
  end

  describe "PATCH #update" do
    let(:user) { create(:user, :confirmed, name: "Original Name", phone_number: "555-0000") }

    before do
      sign_in user
    end

    context "with valid parameters" do
      it "updates user attributes" do
        patch :update, params: {
          user: {
            name: "Updated Name",
            phone_number: "555-9999",
            current_password: "password123"
          }
        }
        user.reload
        expect(user.name).to eq("Updated Name")
        expect(user.phone_number).to eq("555-9999")
      end

      it "permits custom parameters (name, phone_number)" do
        patch :update, params: {
          user: {
            name: "New Name",
            phone_number: "555-1111",
            current_password: "password123"
          }
        }
        user.reload
        expect(user.name).to eq("New Name")
        expect(user.phone_number).to eq("555-1111")
      end
    end

    context "without current password" do
      it "does not update the user" do
        patch :update, params: {
          user: {
            name: "Updated Name",
            phone_number: "555-9999"
          }
        }
        user.reload
        expect(user.name).to eq("Original Name")
      end
    end
  end
end

