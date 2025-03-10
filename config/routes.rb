Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Authentication routes
  get 'login', to: 'sessions#new'
  post 'login', to: 'sessions#create'
  delete 'logout', to: 'sessions#destroy'
  
  # Registration routes
  get 'signup', to: 'users#new'
  post 'signup', to: 'users#create'
  
  # User profile
  resources :users, only: [:show, :edit, :update]
  
  # Organizations
  resources :organizations do
    member do
      get 'members'
      post 'invite'
    end
  end
  
  # Projects
  resources :projects do
    resources :tasks, shallow: true do
      member do
        post 'share'
        post 'assign'
        post 'change_status'
      end
      
      # Task dependencies
      resources :dependencies, only: [:create, :destroy], controller: 'task_dependencies'
    end
  end
  
  # Shared links for external users
  get 'shared/:token', to: 'shared_links#show', as: 'shared_link'
  
  # API routes for Supabase integration
  namespace :api do
    namespace :v1 do
      post 'auth/login', to: 'auth#login'
      post 'auth/register', to: 'auth#register'
      get 'auth/me', to: 'auth#me'
      
      resources :organizations, only: [:index, :show, :create, :update, :destroy]
      resources :projects, only: [:index, :show, :create, :update, :destroy]
      resources :tasks, only: [:index, :show, :create, :update, :destroy]
      
      # Shared links
      resources :shared_links, only: [:create, :update, :destroy]
      
      # External notifications
      resources :notifications, only: [:index, :create, :update], controller: 'external_notifications'
    end
  end

  # Defines the root path route ("/")
  root "gantt#index"
  
  # Add a controller for our Gantt chart
  get "gantt", to: "gantt#index"
  get "dashboard", to: "gantt#index", as: "dashboard"
end
