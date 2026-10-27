module Api
  module V1
    module Admin
      class ImportsController < BaseController
        def index
          render json: { imports: RateImport.order(created_at: :desc).limit(20)
            .as_json(only: [:id, :file_name, :checksum, :rules_version, :status, :summary, :created_at]) }
        end

        def show
          render json: { import: RateImport.find(params[:id]) }
        end
      end
    end
  end
end
