Rails.application.routes.draw do
  # Devise authentication routes
  devise_for :users, controllers: {
    sessions: 'users/sessions',
    registrations: 'users/registrations'
  }

  # Event posts
  resources :event_posts do
    collection do
      get :find
      get :search
    end

    member do
      # Registrations list for organizers
      get :registrations
    end

    resources :event_registrations, only: [:create, :destroy] do
      member do
        # Approve registration (for organizers)
        patch :approve_registration
        # Confirm attendance (for organizers)
        patch :confirm_attendance
      end
    end
  end

  # Leaderboard
  get '/leaderboard', to: 'leaderboard#index'

  # User profiles
  get 'users/search', to: 'users#search', as: :search_users
  resources :users, only: [:show]

  # Email confirmation pending page
  get 'confirmations/pending', to: 'confirmations#pending', as: :confirmations_pending

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "event_posts#index"
end
