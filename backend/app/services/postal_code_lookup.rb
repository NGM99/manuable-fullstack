require "net/http"
require "json"

class PostalCodeLookup
  class NotFound < StandardError; end
  class Unavailable < StandardError; end

  def call(postal_code)
    uri = URI("https://api.zippopotam.us/mx/#{postal_code}")
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 2, read_timeout: 3) do |http|
      http.get(uri.request_uri)
    end
    raise NotFound, postal_code if response.code == "404"
    raise Unavailable unless response.is_a?(Net::HTTPSuccess)
    places = JSON.parse(response.body).fetch("places")
    points = places.map do |place|
      latitude = Float(place.fetch("latitude"))
      longitude = Float(place.fetch("longitude"))
      raise Unavailable unless latitude.finite? && longitude.finite? &&
        latitude.between?(-90, 90) && longitude.between?(-180, 180)
      [latitude, longitude]
    end.sort
    raise Unavailable if points.empty?
    { latitude: (points.sum(&:first) / points.size).round(6),
      longitude: (points.sum(&:last) / points.size).round(6) }
  rescue NotFound
    raise
  rescue StandardError
    raise Unavailable, "Postal lookup unavailable"
  end
end
