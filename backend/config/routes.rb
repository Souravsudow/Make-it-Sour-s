Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  scope ENV.fetch('RAILS_RELATIVE_URL_ROOT', '') do
    # Health check endpoint for load balancers
    get "up" => "rails/health#show", as: :rails_health_check

    # Defines the root path route ("/")
    # root "posts#index"

    namespace :api do
      namespace :v1 do
        resources :resumes, only: [:create] do
          get :preview, on: :collection
        end
        get 'status/events', to: 'status#events'
      end
    end
  end
end
