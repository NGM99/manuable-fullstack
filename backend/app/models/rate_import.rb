class RateImport < ApplicationRecord
  has_many :rates, dependent: :restrict_with_exception
  validates :file_name, :checksum, :rules_version, presence: true
  validates :status, inclusion: { in: %w[pending completed failed] }
end
