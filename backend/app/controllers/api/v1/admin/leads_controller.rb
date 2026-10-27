module Api
  module V1
    module Admin
      class LeadsController < BaseController
        def index
          page = params[:page].to_i.clamp(1, 10_000)
          per_page = 10
          search = params[:q].to_s.strip
          scope = Quote.all
          scope = scope.where("email ILIKE ?", "%#{Quote.sanitize_sql_like(search)}%") if search.present?
          emails = scope.distinct.order(:email).limit(per_page + 1).offset((page - 1) * per_page).pluck(:email)
          has_next = emails.size > per_page
          emails = emails.first(per_page)
          grouped = Quote.where(email: emails).order(quoted_at: :desc, id: :desc).group_by(&:email)
          render json: { page: page, per_page: per_page, has_next: has_next, search: search, leads: emails.map { |email|
            { email: email, quotes: grouped.fetch(email).map(&:public_data) }
          } }
        end
      end
    end
  end
end
