module Api
  module V1
    module Admin
      class LeadsController < BaseController
        def index
          page = params[:page].to_i.clamp(1, 10_000)
          emails = Quote.distinct.order(:email).limit(50).offset((page - 1) * 50).pluck(:email)
          grouped = Quote.where(email: emails).order(quoted_at: :desc).group_by(&:email)
          render json: { page: page, leads: emails.map { |email|
            { email: email, quotes: grouped.fetch(email).map(&:public_data) }
          } }
        end
      end
    end
  end
end
