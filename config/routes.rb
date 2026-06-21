Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  # The comparison table is the homepage — it's the page we want indexed.
  root "models#index"

  resources :models, only: [ :index, :show ]
  resources :providers, only: [ :show ]

  get "compare", to: "comparisons#show", as: :compare
  get "trends",  to: "trends#index",     as: :trends
  get "sources", to: "sources#index",    as: :sources
  get "which-model", to: "pages#which_model", as: :which_model

  # The Guide — browse-by-task model picker. Index is the task chooser; each
  # :task is a FeaturePattern key (e.g. rag, coding_agent). Unknown task → 404.
  get "guide", to: "guide#index", as: :guide
  get "guide/:task", to: "guide#show", as: :guide_task
  get "how-pricing-works", to: "pages#how_pricing_works", as: :how_pricing_works

  # The compact model-page estimate embed (its own Turbo Frame).
  get "models/:id/estimate", to: "embeds#show", as: :model_estimate

  # Education layer — directory index + explainers (each with live-data
  # widgets and an estimator CTA).
  get "learn", to: "learn#index", as: :learn
  get "learn/feature-costs", to: "learn#feature_costs", as: :learn_feature_costs
  get "learn/cost-cutting",  to: "learn#cost_cutting",  as: :learn_cost_cutting

  # Demand probes (capture only — no sending).
  resources :signal_signups, only: :create

  # Public read-only JSON API off PriceCatalog — the citation/backlink flywheel.
  namespace :api do
    namespace :v1 do
      resources :models, only: :index, defaults: { format: :json }
    end
  end

  get "sitemap.xml", to: "sitemaps#index", defaults: { format: "xml" }, as: :sitemap

  namespace :admin do
    root "models#index"
    get    "login",  to: "sessions#new"
    post   "login",  to: "sessions#create"
    delete "logout", to: "sessions#destroy"

    resources :providers, except: :show
    resources :models, except: :show do
      resources :price_points, only: %i[new create edit update destroy]
    end
    resources :market_events, except: :show do
      member { patch :publish }
    end

    # Read-only visibility into the demand-probe signups (the V1 gate metric).
    resources :signal_signups, only: :index do
      collection { get :export }
    end
  end
end
