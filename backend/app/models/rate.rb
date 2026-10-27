class Rate < ApplicationRecord
  belongs_to :carrier
  belongs_to :rate_import
  validates :zone, inclusion: { in: 1..4 }
  validates :weight_min_kg, numericality: { greater_than_or_equal_to: 0 }
  validates :weight_max_kg, numericality: { greater_than: :weight_min_kg }
  validates :price_mxn, numericality: { greater_than: 0, less_than: 10_000_000_000 }
  validates :effective_from, presence: true
  scope :current, ->(date = Date.current) {
    joins(:carrier).where(carriers: { active: true }).where("effective_from <= ?", date)
      .where("effective_until IS NULL OR effective_until > ?", date)
  }
end
