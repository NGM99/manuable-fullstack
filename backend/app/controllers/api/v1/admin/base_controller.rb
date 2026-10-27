require "digest"

module Api
  module V1
    module Admin
      class BaseController < ApplicationController
        include ActionController::HttpAuthentication::Basic::ControllerMethods
        before_action :authenticate

        private

        def authenticate
          authenticate_or_request_with_http_basic("Comercial") do |username, password|
            expected_user = Digest::SHA256.hexdigest(ENV.fetch("ADMIN_USER"))
            expected_password = Digest::SHA256.hexdigest(ENV.fetch("ADMIN_PASSWORD"))
            user_ok = ActiveSupport::SecurityUtils.secure_compare(Digest::SHA256.hexdigest(username.to_s), expected_user)
            password_ok = ActiveSupport::SecurityUtils.secure_compare(Digest::SHA256.hexdigest(password.to_s), expected_password)
            user_ok && password_ok
          end
        end
      end
    end
  end
end
