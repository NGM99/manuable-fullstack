Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  namespace :api do
    namespace :v1 do
      get "health", to: "health#show"
      resources :quotes, only: :create
      namespace :admin do
        get "stats", to: "stats#index"
        resources :leads, only: :index
        resources :quotes, only: :show
        resources :imports, only: [:index, :show]
      end
    end
  end
end
