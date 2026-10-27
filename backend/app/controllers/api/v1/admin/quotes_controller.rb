module Api
  module V1
    module Admin
      class QuotesController < BaseController
        def show
          quote = Quote.find(params[:id])
          render json: { quote: quote.public_data.merge("email" => quote.email, "metadata" => quote.metadata) }
        end
      end
    end
  end
end
