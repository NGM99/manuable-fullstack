class CreateQuotingData < ActiveRecord::Migration[8.1]
  def change
    create_table :carriers do |t|
      t.string :external_id, null: false
      t.string :name, null: false
      t.string :service_type, null: false
      t.boolean :active, null: false, default: false
      t.timestamps
    end
    add_index :carriers, :external_id, unique: true
    create_table :rate_imports do |t|
      t.string :file_name, null: false
      t.string :checksum, null: false
      t.string :rules_version, null: false
      t.string :status, null: false, default: "pending"
      t.jsonb :summary, null: false, default: {}
      t.jsonb :rows, null: false, default: []
      t.timestamps
    end
    add_index :rate_imports, [:file_name, :checksum, :rules_version],
      unique: true, where: "status = 'completed'", name: "completed_import_files"
    create_table :rates do |t|
      t.references :carrier, null: false, foreign_key: true
      t.references :rate_import, null: false, foreign_key: true
      t.integer :source_line, null: false
      t.integer :zone, null: false
      t.decimal :weight_min_kg, precision: 12, scale: 3, null: false
      t.decimal :weight_max_kg, precision: 12, scale: 3, null: false
      t.decimal :price_mxn, precision: 12, scale: 2, null: false
      t.integer :delivery_days_min
      t.integer :delivery_days_max
      t.date :effective_from, null: false
      t.date :effective_until
      t.timestamps
    end
    add_index :rates, [:carrier_id, :zone, :weight_min_kg, :weight_max_kg, :effective_from],
      unique: true, name: "unique_carrier_weight_rate"
    add_index :rates, [:zone, :effective_from]
    add_check_constraint :rates, "zone BETWEEN 1 AND 4", name: "valid_rate_zone"
    add_check_constraint :rates,
      "weight_min_kg >= 0 AND weight_max_kg > weight_min_kg AND weight_max_kg < 1000000000",
      name: "valid_rate_weight"
    add_check_constraint :rates, "price_mxn > 0 AND price_mxn < 10000000000", name: "valid_rate_price"
    add_check_constraint :rates, "effective_until IS NULL OR effective_until > effective_from",
      name: "valid_rate_dates"
    create_table :quotes do |t|
      t.string :email, limit: 254, null: false
      t.string :origin_postal_code, limit: 5, null: false
      t.string :destination_postal_code, limit: 5, null: false
      t.decimal :weight_kg, precision: 12, scale: 3, null: false
      t.decimal :distance_km, precision: 12, scale: 6
      t.integer :zone
      t.string :status, null: false, default: "pending"
      t.string :error_code
      t.jsonb :options, null: false, default: []
      t.jsonb :metadata, null: false, default: {}
      t.datetime :quoted_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
      t.timestamps
    end
    add_index :quotes, :email
    add_index :quotes, :quoted_at
    add_check_constraint :quotes, "weight_kg > 0 AND weight_kg < 1000000000", name: "valid_quote_weight"
    add_check_constraint :quotes,
      "origin_postal_code ~ '^[0-9]{5}$' AND destination_postal_code ~ '^[0-9]{5}$'",
      name: "valid_quote_postal_codes"
    add_check_constraint :quotes, "jsonb_typeof(options) = 'array'", name: "quote_options_array"
  end
end
