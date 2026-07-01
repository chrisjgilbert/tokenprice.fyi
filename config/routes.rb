Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  # The comparison table is the homepage — it's the page we want indexed.
  root "models#index"

  resources :models, only: [ :index, :show ]
  resources :providers, only: [ :show ]

  get "compare", to: "comparisons#show", as: :compare
  get "events",  to: "events#index",     as: :events
  get "sources", to: "sources#index",    as: :sources
  get "which-model", to: redirect("/guide", status: 301)
  # The market-events timeline replaced the old price-trends chart; 301 the
  # retired URL to preserve inbound links and bookmarks.
  get "trends", to: redirect("/events", status: 301)

  # The Guide — browse-by-task model picker. Index is the task chooser; each
  # :task is a FeaturePattern key (e.g. rag, coding_agent). Unknown task → 404.
  get "guide", to: "guide#index", as: :guide
  # The coding-agent slug shipped with an underscore; 301 the legacy URL to the
  # hyphenated one to preserve link equity. Must precede the generic task route.
  get "guide/coding_agent", to: redirect("/guide/coding-agent", status: 301)
  get "guide/:task", to: "guide#show", as: :guide_task
  get "how-pricing-works", to: "pages#how_pricing_works", as: :how_pricing_works

  # Education layer — directory index + explainers (each with live-data
  # widgets).
  get "learn", to: "learn#index", as: :learn
  get "learn/reasoning", to: "learn#reasoning", as: :learn_reasoning
  get "learn/feature-costs", to: "learn#feature_costs", as: :learn_feature_costs
  get "learn/cost-cutting",  to: "learn#cost_cutting",  as: :learn_cost_cutting

  # Public read-only JSON API off PriceCatalog — the citation/backlink flywheel.
  namespace :api do
    namespace :v1 do
      resources :models, only: :index, defaults: { format: :json }
    end
  end

  get "sitemap.xml", to: "sitemaps#index", defaults: { format: "xml" }, as: :sitemap
  get "llms.txt",    to: "pages#llms_txt",  defaults: { format: "txt" }, as: :llms_txt

  # Lets BlueSky verify tokenprice.fyi as the account's handle (AT Protocol
  # resolves the domain by fetching this DID).
  get "/.well-known/atproto-did", to: "pages#atproto_did"

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
      # Regenerate the "so what" out of band. A namespaced sub-resource with a
      # standard action, per the house style, rather than another custom verb.
      resource :insight, only: :create, controller: "market_event_insights"
    end

    # Active Job / Solid Queue dashboard, behind the admin session auth above.
    mount MissionControl::Jobs::Engine, at: "jobs"
  end
end
