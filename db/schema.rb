# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_27_000000) do
  create_table "ai_models", force: :cascade do |t|
    t.text "best_for"
    t.integer "context_window"
    t.datetime "created_at", null: false
    t.text "description"
    t.json "input_modalities", default: [], null: false
    t.text "limitations"
    t.integer "max_output_tokens"
    t.string "name", null: false
    t.string "openrouter_id"
    t.json "output_modalities", default: [], null: false
    t.integer "provider_id", null: false
    t.date "released_on"
    t.string "slug", null: false
    t.string "source", default: "manual", null: false
    t.string "status", default: "active", null: false
    t.text "strengths"
    t.string "tier", default: "frontier", null: false
    t.datetime "updated_at", null: false
    t.index ["openrouter_id"], name: "index_ai_models_on_openrouter_id", unique: true
    t.index ["provider_id"], name: "index_ai_models_on_provider_id"
    t.index ["slug"], name: "index_ai_models_on_slug", unique: true
    t.index ["source"], name: "index_ai_models_on_source"
    t.index ["status"], name: "index_ai_models_on_status"
    t.index ["tier"], name: "index_ai_models_on_tier"
  end

  create_table "market_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "event_date", null: false
    t.string "kind", default: "market", null: false
    t.text "note"
    t.string "source"
    t.string "source_url"
    t.string "status", default: "published", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["event_date"], name: "index_market_events_on_event_date"
    t.index ["kind"], name: "index_market_events_on_kind"
    t.index ["status"], name: "index_market_events_on_status"
  end

  create_table "news_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "curated_at"
    t.string "kind"
    t.integer "market_event_id"
    t.datetime "notified_at"
    t.datetime "published_at"
    t.string "rationale"
    t.boolean "relevant"
    t.string "source", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.index ["curated_at"], name: "index_news_items_on_curated_at"
    t.index ["notified_at"], name: "index_news_items_on_notified_at"
    t.index ["published_at"], name: "index_news_items_on_published_at"
    t.index ["url"], name: "index_news_items_on_url", unique: true
  end

  create_table "price_points", force: :cascade do |t|
    t.integer "ai_model_id", null: false
    t.decimal "cached_input_per_mtok", precision: 12, scale: 6
    t.datetime "created_at", null: false
    t.date "effective_on", null: false
    t.decimal "input_per_mtok", precision: 12, scale: 6, null: false
    t.string "note"
    t.decimal "output_per_mtok", precision: 12, scale: 6, null: false
    t.string "source"
    t.datetime "updated_at", null: false
    t.index ["ai_model_id", "effective_on"], name: "index_price_points_on_ai_model_id_and_effective_on", unique: true
    t.index ["ai_model_id"], name: "index_price_points_on_ai_model_id"
  end

  create_table "providers", force: :cascade do |t|
    t.string "accent"
    t.string "country"
    t.string "country_code"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.string "website"
    t.index ["country_code"], name: "index_providers_on_country_code"
    t.index ["slug"], name: "index_providers_on_slug", unique: true
  end

  add_foreign_key "ai_models", "providers"
  add_foreign_key "price_points", "ai_models"
end
