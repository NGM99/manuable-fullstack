class Carrier < ApplicationRecord
  has_many :rates, dependent: :restrict_with_exception
  validates :external_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :service_type, inclusion: { in: %w[air ground] }
  validates :active, inclusion: { in: [true, false] }
end
