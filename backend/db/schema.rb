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

ActiveRecord::Schema[8.1].define(version: 2026_10_27_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "carriers", force: :cascade do |t|
    t.string "external_id", null: false
    t.string "name", null: false
    t.string "service_type", null: false
    t.boolean "active", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "billing_rules", default: [], null: false
    t.index ["external_id"], name: "index_carriers_on_external_id", unique: true
    t.check_constraint "jsonb_typeof(billing_rules) = 'array'::text", name: "carrier_billing_rules_array"
  end

  create_table "quotes", force: :cascade do |t|
    t.string "email", limit: 254, null: false
    t.string "origin_postal_code", limit: 5, null: false
    t.string "destination_postal_code", limit: 5, null: false
    t.decimal "weight_kg", precision: 12, scale: 3, null: false
    t.decimal "distance_km", precision: 12, scale: 6
    t.integer "zone"
    t.string "status", default: "pending", null: false
    t.string "error_code"
    t.jsonb "options", default: [], null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "quoted_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "length_cm", precision: 12, scale: 3
    t.decimal "width_cm", precision: 12, scale: 3
    t.decimal "height_cm", precision: 12, scale: 3
    t.string "source", default: "web", null: false
    t.string "external_reference"
    t.datetime "valid_until", null: false
    t.index ["email"], name: "index_quotes_on_email"
    t.index ["external_reference"], name: "index_quotes_on_external_reference", unique: true
    t.index ["quoted_at"], name: "index_quotes_on_quoted_at"
    t.check_constraint "jsonb_typeof(options) = 'array'::text", name: "quote_options_array"
    t.check_constraint "length_cm IS NULL AND width_cm IS NULL AND height_cm IS NULL OR length_cm IS NOT NULL AND width_cm IS NOT NULL AND height_cm IS NOT NULL AND length_cm > 0::numeric AND width_cm > 0::numeric AND height_cm > 0::numeric AND length_cm < 1000000::numeric AND width_cm < 1000000::numeric AND height_cm < 1000000::numeric", name: "valid_quote_dimensions"
    t.check_constraint "origin_postal_code::text ~ '^[0-9]{5}$'::text AND destination_postal_code::text ~ '^[0-9]{5}$'::text", name: "valid_quote_postal_codes"
    t.check_constraint "source::text = ANY (ARRAY['web'::character varying, 'manual'::character varying]::text[])", name: "valid_quote_source"
    t.check_constraint "weight_kg > 0::numeric AND weight_kg < 1000000000::numeric", name: "valid_quote_weight"
  end

  create_table "rate_imports", force: :cascade do |t|
    t.string "file_name", null: false
    t.string "checksum", null: false
    t.string "rules_version", null: false
    t.string "status", default: "pending", null: false
    t.jsonb "summary", default: {}, null: false
    t.jsonb "rows", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["file_name", "checksum", "rules_version"], name: "completed_import_files", unique: true, where: "((status)::text = 'completed'::text)"
  end

  create_table "rates", force: :cascade do |t|
    t.bigint "carrier_id", null: false
    t.bigint "rate_import_id", null: false
    t.integer "source_line", null: false
    t.integer "zone", null: false
    t.decimal "weight_min_kg", precision: 12, scale: 3, null: false
    t.decimal "weight_max_kg", precision: 12, scale: 3, null: false
    t.decimal "price_mxn", precision: 12, scale: 2, null: false
    t.integer "delivery_days_min"
    t.integer "delivery_days_max"
    t.date "effective_from", null: false
    t.date "effective_until"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["carrier_id", "zone", "weight_min_kg", "weight_max_kg", "effective_from"], name: "unique_carrier_weight_rate", unique: true
    t.index ["carrier_id"], name: "index_rates_on_carrier_id"
    t.index ["rate_import_id"], name: "index_rates_on_rate_import_id"
    t.index ["zone", "effective_from"], name: "index_rates_on_zone_and_effective_from"
    t.check_constraint "effective_until IS NULL OR effective_until > effective_from", name: "valid_rate_dates"
    t.check_constraint "price_mxn > 0::numeric AND price_mxn < '10000000000'::bigint::numeric", name: "valid_rate_price"
    t.check_constraint "weight_min_kg >= 0::numeric AND weight_max_kg > weight_min_kg AND weight_max_kg < 1000000000::numeric", name: "valid_rate_weight"
    t.check_constraint "zone >= 1 AND zone <= 4", name: "valid_rate_zone"
  end

  add_foreign_key "rates", "carriers"
  add_foreign_key "rates", "rate_imports"
end
