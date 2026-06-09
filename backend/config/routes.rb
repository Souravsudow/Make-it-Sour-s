Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  scope ENV.fetch('RAILS_RELATIVE_URL_ROOT', '') do
    # Health check endpoint for load balancers
    get "up" => "rails/health#show", as: :rails_health_check

    # Defines the root path route ("/")
    # root "posts#index"

    # API v1 routes — accessible at /api/v1/... (used in local dev)
    namespace :api do
      namespace :v1 do
        resources :resumes, only: [:create] do
          get :preview, on: :collection
        end
        get 'status/events', to: 'status#events'
      end
    end

    # Vercel-friendly routes — Vercel strips the /api prefix,
    # so Rails receives /v1/... instead of /api/v1/...
    scope module: 'api/v1', path: 'v1', as: 'v1' do
      resources :resumes, only: [:create] do
        get :preview, on: :collection
      end
      get 'status/events', to: 'status#events'
    end
  end
end
