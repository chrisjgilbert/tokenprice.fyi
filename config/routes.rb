Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  # The comparison table is the homepage — it's the page we want indexed.
  root "models#index"

  resources :models, only: [ :index, :show ]
  resources :providers, only: [ :show ]

  get "compare", to: "comparisons#show", as: :compare
  get "trends",  to: "trends#index",     as: :trends

  get "sitemap.xml", to: "sitemaps#index", defaults: { format: "xml" }, as: :sitemap

  namespace :admin do
    root "models#index"
    get    "login",  to: "sessions#new"
    post   "login",  to: "sessions#create"
    delete "logout", to: "sessions#destroy"

    resources :providers
    resources :models do
      resources :price_points, only: %i[new create edit update destroy]
    end
  end
end
