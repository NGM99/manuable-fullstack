ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
abort("RSpec requires RAILS_ENV=test") unless Rails.env.test?
abort("RSpec requires the isolated manuable_test database") unless
  ActiveRecord::Base.connection_db_config.database == "manuable_test"
require "rspec/rails"
ActiveRecord::Migration.maintain_test_schema!
RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.filter_rails_from_backtrace!
end
