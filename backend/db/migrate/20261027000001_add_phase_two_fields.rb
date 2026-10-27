class AddPhaseTwoFields < ActiveRecord::Migration[8.1]
  def change
    add_column :carriers, :billing_rules, :jsonb, null: false, default: []
    add_check_constraint :carriers, "jsonb_typeof(billing_rules) = 'array'", name: "carrier_billing_rules_array"
    [:length_cm, :width_cm, :height_cm].each do |field|
      add_column :quotes, field, :decimal, precision: 12, scale: 3
    end
    add_check_constraint :quotes,
      "(length_cm IS NULL AND width_cm IS NULL AND height_cm IS NULL) OR " \
      "(length_cm IS NOT NULL AND width_cm IS NOT NULL AND height_cm IS NOT NULL AND " \
      "length_cm > 0 AND width_cm > 0 AND height_cm > 0 AND " \
      "length_cm < 1000000 AND width_cm < 1000000 AND height_cm < 1000000)",
      name: "valid_quote_dimensions"
    add_column :quotes, :source, :string, null: false, default: "web"
    add_column :quotes, :external_reference, :string
    add_index :quotes, :external_reference, unique: true
    add_check_constraint :quotes, "source IN ('web', 'manual')", name: "valid_quote_source"
    add_column :quotes, :valid_until, :datetime
    reversible do |direction|
      direction.up do
        execute "UPDATE quotes SET valid_until = quoted_at + INTERVAL '30 days'"
      end
    end
    change_column_null :quotes, :valid_until, false
  end
end
