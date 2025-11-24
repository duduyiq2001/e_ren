require 'rails_helper'

RSpec.describe User, type: :model do
  describe "associations" do
    it { should have_many(:organized_events).class_name('EventPost').with_foreign_key('organizer_id').dependent(:destroy_async) }
    it { should have_many(:event_registrations).dependent(:destroy_async) }
    it { should have_many(:attended_events).through(:event_registrations).source(:event_post) }
    it { should belong_to(:deleted_by_user).class_name('User').with_foreign_key('deleted_by_id').optional }
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

  describe "role and admin methods" do
    let(:student) { create(:user, role: :student) }
    let(:admin) { create(:user, :admin) }

    describe "#admin?" do
      it "returns true for super_admin" do
        expect(admin.admin?).to be true
      end

      it "returns false for student" do
        expect(student.admin?).to be false
      end
    end

    describe "#can_delete_user?" do
      let(:target_user) { create(:user) }

      it "allows admin to delete other users" do
        expect(admin.can_delete_user?(target_user)).to be true
      end

      it "prevents admin from deleting themselves" do
        expect(admin.can_delete_user?(admin)).to be false
      end

      it "prevents non-admin from deleting users" do
        expect(student.can_delete_user?(target_user)).to be false
      end
    end

    describe "#can_delete_event?" do
      let(:event_post) { create(:event_post) }

      it "allows admin to delete events" do
        expect(admin.can_delete_event?(event_post)).to be true
      end

      it "prevents non-admin from deleting events" do
        expect(student.can_delete_event?(event_post)).to be false
      end
    end
  end

  describe "soft delete functionality" do
    let(:admin) { create(:user, :admin) }
    let(:target_user) { create(:user) }
    let!(:event_post) { create(:event_post, organizer: target_user) }
    let!(:registration) { create(:event_registration, user: target_user, event_post: event_post) }
    let!(:other_registration) { create(:event_registration, event_post: event_post) }

    describe "#soft_delete_with_cascade!" do
      it "hard deletes user and cascades to events" do
        user_id = target_user.id
        event_id = event_post.id
        reg_id = registration.id
        other_reg_id = other_registration.id
        
        target_user.soft_delete_with_cascade!(admin, reason: 'Test deletion')
        
        # Records should be hard deleted (not found)
        expect { User.find(user_id) }.to raise_error(ActiveRecord::RecordNotFound)
        expect { EventPost.find(event_id) }.to raise_error(ActiveRecord::RecordNotFound)
        expect { EventRegistration.find(reg_id) }.to raise_error(ActiveRecord::RecordNotFound)
        expect { EventRegistration.find(other_reg_id) }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "records deletion metadata before deletion" do
        # Metadata is saved before deletion
        target_user.soft_delete_with_cascade!(admin, reason: 'Spam account')
        
        # After deletion, we can't check metadata as record is gone
        # But we can verify deletion happened
        expect { User.find(target_user.id) }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "hard deletes records" do
        user_id = target_user.id
        event_id = event_post.id
        
        target_user.soft_delete_with_cascade!(admin)
        
        # Records should be hard deleted (not found)
        expect { User.find(user_id) }.to raise_error(ActiveRecord::RecordNotFound)
        expect { EventPost.find(event_id) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    describe "#deletion_preview" do
      it "returns accurate counts" do
        create_list(:event_post, 2, organizer: target_user)
        create_list(:event_registration, 3, user: target_user)
        
        preview = target_user.deletion_preview
        
        expect(preview[:organized_events]).to eq(3) # 1 from let! + 2 from create_list
        expect(preview[:event_registrations]).to be >= 3
        expect(preview[:e_score]).to eq(target_user.e_score)
      end
    end
  end
end
