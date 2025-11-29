require 'rails_helper'

RSpec.describe 'Admin::EventCategories', type: :request do
  let(:admin) { create(:user, :admin) }
  let(:student) { create(:user) }
  let!(:category) { create(:event_category, name: 'Sports') }

  describe 'GET /admin/event_categories' do
    context 'as admin' do
      before { sign_in admin }

      it 'returns all categories' do
        create(:event_category, name: 'Music')
        get admin_event_categories_path

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json.map { |c| c['name'] }).to include('Sports', 'Music')
      end
    end

    context 'as non-admin' do
      before { sign_in student }

      it 'returns forbidden' do
        get admin_event_categories_path
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET /admin/event_categories/:id' do
    before { sign_in admin }

    it 'returns the category' do
      get admin_event_category_path(category)

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['name']).to eq('Sports')
    end
  end

  describe 'POST /admin/event_categories' do
    context 'as non-admin' do
      before { sign_in student }

      it 'returns forbidden' do
        post admin_event_categories_path, params: {
          event_category: { name: 'Hacking' }
        }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when not signed in' do
      it 'redirects to login' do
        post admin_event_categories_path, params: {
          event_category: { name: 'Hacking' }
        }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'as admin' do
      before { sign_in admin }

      it 'creates a new category' do
        expect {
          post admin_event_categories_path, params: {
            event_category: { name: 'Gaming', color: '#FF5733' }
          }
        }.to change(EventCategory, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['name']).to eq('Gaming')
        expect(json['color']).to eq('#FF5733')
      end

      it 'returns errors for invalid data' do
        post admin_event_categories_path, params: {
          event_category: { name: '' }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to include("Name can't be blank")
      end

      it 'returns error for duplicate name' do
        post admin_event_categories_path, params: {
          event_category: { name: 'Sports' }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to include('Name has already been taken')
      end
    end
  end

  describe 'PATCH /admin/event_categories/:id' do
    context 'as non-admin' do
      before { sign_in student }

      it 'returns forbidden' do
        patch admin_event_category_path(category), params: {
          event_category: { name: 'Hacked' }
        }
        expect(response).to have_http_status(:forbidden)
        expect(category.reload.name).to eq('Sports')
      end
    end

    context 'as admin' do
      before { sign_in admin }

      it 'updates the category' do
        patch admin_event_category_path(category), params: {
          event_category: { name: 'Athletics', color: '#00FF00' }
        }

        expect(response).to have_http_status(:success)
        category.reload
        expect(category.name).to eq('Athletics')
        expect(category.color).to eq('#00FF00')
      end

      it 'returns errors for invalid data' do
        patch admin_event_category_path(category), params: {
          event_category: { name: '' }
        }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'DELETE /admin/event_categories/:id' do
    context 'as non-admin' do
      before { sign_in student }

      it 'returns forbidden' do
        delete admin_event_category_path(category)
        expect(response).to have_http_status(:forbidden)
        expect(EventCategory.find(category.id)).to be_present
      end
    end

    context 'as admin' do
      before { sign_in admin }

      context 'when category has no events' do
        it 'deletes the category' do
          expect {
            delete admin_event_category_path(category)
          }.to change(EventCategory, :count).by(-1)

          expect(response).to have_http_status(:success)
        end
      end

      context 'when category has events' do
        before do
          create(:event_post, event_category: category)
        end

        it 'returns error and does not delete' do
          expect {
            delete admin_event_category_path(category)
          }.not_to change(EventCategory, :count)

          expect(response).to have_http_status(:unprocessable_entity)
          json = JSON.parse(response.body)
          expect(json['error']).to include('Cannot delete category with existing events')
        end
      end
    end
  end
end
