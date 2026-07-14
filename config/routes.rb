Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  # The comparison table is the homepage — it's the page we want indexed.
  root "models#index"

  # The models table tabs by pricing family. Language is the root (per-token
  # prices); embeddings, speech to text, image generation, and video generation
  # each get their own indexable URL and bill in their own native unit. All
  # render models#index, resolved via the `category` param off the ModelCategory
  # registry.
  get "embeddings", to: "models#index", defaults: { category: "embeddings" }, as: :embeddings
  get "rerank", to: "models#index", defaults: { category: "rerank" }, as: :rerank
  get "speech-to-text", to: "models#index", defaults: { category: "speech-to-text" }, as: :speech_to_text
  get "text-to-speech", to: "models#index", defaults: { category: "text-to-speech" }, as: :text_to_speech
  get "image-generation", to: "models#index", defaults: { category: "image" }, as: :image_generation
  get "video-generation", to: "models#index", defaults: { category: "video" }, as: :video_generation

  resources :models, only: [ :index, :show ]
  resources :providers, only: [ :show ]

  get "compare", to: "comparisons#show", as: :compare
  get "events",  to: "events#index",     as: :events
  # Recent catalog price changes (last 30 days) — the raw, automated feed that
  # backs the Slack price-moves digest. Deliberately off the nav and separate
  # from the curated /events timeline; the digest links here.
  get "changes", to: "price_changes#index", as: :price_changes
  # The public raw news feed was retired (no traffic); its curated distillation
  # lives at /events, and the ingestion pipeline still feeds it. 301 inbound
  # links and bookmarks there rather than 404.
  get "news",    to: redirect("/events", status: 301)
  get "sources", to: "sources#index",    as: :sources
  # The flagship price-over-time page was retired; the recent-price-changes strip
  # it carried now lives on /events. 301 inbound links there rather than 404.
  get "trends",  to: redirect("/events", status: 301)
  # The task-based Guide was removed. 301 its URLs — and the legacy /which-model
  # alias that used to point at it — to the homepage so inbound links and
  # bookmarks keep landing on the models table. The /guide/:task catch covers
  # every former task page (including the old /guide/coding_agent spelling).
  get "which-model", to: redirect("/", status: 301)
  get "guide", to: redirect("/", status: 301)
  get "guide/:task", to: redirect("/", status: 301)
  get "how-pricing-works", to: "pages#how_pricing_works", as: :how_pricing_works

  # Education layer — directory index + explainers (each with live-data
  # widgets).
  get "learn", to: "learn#index", as: :learn
  get "learn/reasoning", to: "learn#reasoning", as: :learn_reasoning
  get "learn/feature-costs", to: "learn#feature_costs", as: :learn_feature_costs
  get "learn/cost-cutting",  to: "learn#cost_cutting",  as: :learn_cost_cutting

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
      # Regenerate the launch "so what" out of band. A namespaced sub-resource
      # with a standard action, per the house style, rather than a custom verb.
      resource :insight, only: :create, controller: "ai_model_insights"
    end
    resources :market_events, except: :show do
      member { patch :publish }
      # Regenerate the "so what" out of band. A namespaced sub-resource with a
      # standard action, per the house style, rather than another custom verb.
      resource :insight, only: :create, controller: "market_event_insights"
    end

    # Review queue for model candidates mined from launch news by ModelCurationJob.
    # accept/dismiss are the two review verbs; accept creates the AiModel row.
    resources :model_candidates, only: :index do
      member do
        patch :accept
        patch :dismiss
      end
    end

    # Active Job / Solid Queue dashboard, behind the admin session auth above.
    mount MissionControl::Jobs::Engine, at: "jobs"
  end
end
