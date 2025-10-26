Rails.application.routes.draw do
  # Event posts
  get "event_posts/index"
  get "event_posts/find"
  get "event_posts/search"
  resources :event_posts, only: [:show, :new, :create, :edit, :update, :destroy] do
    resources :event_registrations, only: [:create, :destroy] do
      # Confirm attendance (for organizers)
      patch 'confirm_attendance', on: :member
    end
    # Registrations list for organizers
    get 'registrations', on: :member
  end

  # Leaderboard
  get '/leaderboard', to: 'leaderboard#index'

  # Authentication
  get '/signup', to: 'users#new'
  post '/signup', to: 'users#create'
  get '/login', to: 'sessions#new'
  post '/login', to: 'sessions#create'
  delete '/logout', to: 'sessions#destroy'

  # User profiles
  get 'users/search', to: 'users#search', as: :search_users
  resources :users, only: [:show]

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
