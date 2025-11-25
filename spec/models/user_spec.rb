require 'rails_helper'

RSpec.describe User, type: :model do
  describe "associations" do
    it { should have_many(:organized_events).class_name('EventPost').with_foreign_key('organizer_id').dependent(:destroy_async) }
    it { should have_many(:event_registrations).dependent(:destroy_async) }
    it { should have_many(:attended_events).through(:event_registrations).source(:event_post) }
  end

  describe "validations" do
    subject { build(:user) }

    it { should validate_presence_of(:email) }
    # Devise validates email uniqueness case-insensitively by default
    it { should validate_uniqueness_of(:email).case_insensitive }
    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_most(100) }
    it { should validate_numericality_of(:e_score).only_integer.is_greater_than_or_equal_to(0) }

    context "password validations" do
      it "requires password on create" do
        user = build(:user, password: nil, password_confirmation: nil)
        expect(user).not_to be_valid
        expect(user.errors[:password]).to include("can't be blank")
      end

      it "requires password to be at least 6 characters" do
        user = build(:user, password: "12345", password_confirmation: "12345")
        expect(user).not_to be_valid
        expect(user.errors[:password]).to include("is too short (minimum is 6 characters)")
      end

      it "is valid with password of 6 or more characters" do
        user = build(:user, password: "123456", password_confirmation: "123456")
        expect(user).to be_valid
      end

      it "requires password_confirmation to match password" do
        user = build(:user, password: "password123", password_confirmation: "different")
        expect(user).not_to be_valid
        expect(user.errors[:password_confirmation]).to include("doesn't match Password")
      end
    end

    context "email format" do
      it "is valid with a proper email format" do
        user = build(:user)  # uses sequence: userN@wustl.edu
        expect(user).to be_valid
      end

      it "is invalid with an improper email format" do
        user = build(:user, email: "invalid-email")
        expect(user).not_to be_valid
      end
    end

    context "phone_number format" do
      it "is valid with a proper phone number" do
        user = build(:user, phone_number: "+1234567890")
        expect(user).to be_valid
      end

      it "is valid when phone_number is blank" do
        user = build(:user, phone_number: nil)
        expect(user).to be_valid
      end

      it "is invalid with improper characters" do
        user = build(:user, phone_number: "abc123")
        expect(user).not_to be_valid
      end
    end
  end

  describe "#valid_password?" do
    let(:user) { create(:user, password: "password123") }

    it "returns true when password is correct" do
      expect(user.valid_password?("password123")).to be true
    end

    it "returns false when password is incorrect" do
      expect(user.valid_password?("wrong_password")).to be false
    end
  end

  describe "instance methods" do
    let(:user) { create(:user) }
    let(:event_post) { create(:event_post, organizer: user) }
    let(:attended_event) { create(:event_post) }

    before do
      create(:event_registration, user: user, event_post: attended_event)
    end

    describe "#attending?" do
      it "returns true if user is attending the event" do
        expect(user.attending?(attended_event)).to be true
      end

      it "returns false if user is not attending the event" do
        expect(user.attending?(event_post)).to be false
      end
    end

    describe "#organizing?" do
      it "returns true if user is organizing the event" do
        expect(user.organizing?(event_post)).to be true
      end

      it "returns false if user is not organizing the event" do
        expect(user.organizing?(attended_event)).to be false
      end
    end
  end
end
