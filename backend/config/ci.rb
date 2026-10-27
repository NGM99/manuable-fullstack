ENV["RAILS_ENV"] = "test"

CI.run do
  step "Prepare database", "bundle exec rails db:prepare"
  step "RSpec", "bundle exec rspec"
end
