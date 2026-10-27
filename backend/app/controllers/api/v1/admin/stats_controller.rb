module Api
  module V1
    module Admin
      class StatsController < BaseController
        def index
          day = "(quoted_at AT TIME ZONE 'UTC' AT TIME ZONE 'America/Monterrey')::date"
          records = Quote.select(Arel.sql("#{day} AS day, source, COUNT(*) AS total, " \
            "COUNT(*) FILTER (WHERE jsonb_array_length(options) = 0 AND status <> 'pending') AS without_options"))
            .group(Arel.sql(day), :source).order(Arel.sql("day DESC"), :source).limit(60)
          render json: { days: records.map { |row|
            { date: row["day"].to_s, source: row.source, total: row["total"].to_i,
              without_options: row["without_options"].to_i }
          } }
        end
      end
    end
  end
end
