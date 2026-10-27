require "rails_helper"
RSpec.describe "Test database" do
  it "uses an isolated PostgreSQL database on version 15 or later" do
    connection = ActiveRecord::Base.connection
    expect(connection.adapter_name).to eq("PostgreSQL")
    expect(connection.select_value("SELECT current_database()")).to eq("manuable_test")
    expect(connection.select_value("SHOW server_version_num").to_i).to be >= 150000
  end
end
