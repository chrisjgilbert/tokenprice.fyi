Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  # The comparison table is the homepage — it's the page we want indexed.
  root "models#index"

  resources :models, only: [ :index, :show ]
  resources :providers, only: [ :show ]

  get "compare", to: "comparisons#show", as: :compare
  get "trends",  to: "trends#index",     as: :trends
end
