# frozen_string_literal: true

require "erb"
require "json"
require "net/http"

# The official client for the Mapricot API: address and place search, reverse geocoding, nearby places, routing,
# and IP geolocation. See https://mapricot.com/docs/ruby/.
module Mapricot
  VERSION = "0.6.0"

  # An error response from the API.
  class Error < StandardError
    attr_reader :status, :code, :request_id

    def initialize(status, code, message, request_id)
      super(message)
      @status = status
      @code = code
      @request_id = request_id
    end
  end

  # Methods are grouped by product, as in client.geocoding.search. Each returns the API's JSON as a Hash with string
  # keys, as in https://mapricot.com/api-reference/.
  class Client
    attr_reader :geocoding, :places, :routing, :ip_geolocation

    def initialize(api_key:, base_url: "https://api.mapricot.com", timeout: 30, max_retries: 2)
      raise ArgumentError, "Pass api_key:, a Mapricot key." if api_key.nil? || api_key.empty?

      @api_key = api_key
      @base_url = base_url
      @timeout = timeout
      @max_retries = max_retries
      @geocoding = GeocodingService.new(method(:get))
      @places = PlacesService.new(method(:get))
      @routing = RoutingService.new(method(:post))
      @ip_geolocation = IpGeolocationService.new(method(:get))
    end

    # The key's account. Not billed, so it checks a key for free.
    def account
      get("/account")
    end

    private

    def get(path, **params)
      uri = URI(@base_url + path)
      query = params.compact.transform_values { |value| query_value(value) }
      uri.query = URI.encode_www_form(query) unless query.empty?
      request(Net::HTTP::Get, uri)
    end

    def post(path, body)
      request(Net::HTTP::Post, URI(@base_url + path), JSON.generate(body.compact))
    end

    def request(method, uri, body = nil)
      attempt = 0
      loop do
        req = method.new(uri)
        req["Authorization"] = "Bearer #{@api_key}"
        req["User-Agent"] = "mapricot-ruby/#{VERSION}"
        if body
          req["Content-Type"] = "application/json"
          req.body = body
        end
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                                       open_timeout: @timeout, read_timeout: @timeout) do |http|
          http.request(req)
        end
        return JSON.parse(response.body) if response.is_a?(Net::HTTPOK)

        error = error_from(response)
        raise error if attempt >= @max_retries || !retryable?(error)

        sleep(0.5 * 2**attempt)
        attempt += 1
      end
    end

    def query_value(value)
      case value
      when Hash then "#{value.fetch(:lat)},#{value.fetch(:lon)}"
      when Array then value.join(",")
      else value.to_s
      end
    end

    def error_from(response)
      request_id = response["X-Request-Id"]
      error = JSON.parse(response.body).fetch("error")
      Error.new(response.code.to_i, error.fetch("code"), error.fetch("message"), request_id)
    rescue JSON::ParserError, KeyError, TypeError
      Error.new(response.code.to_i, "unknown", "HTTP #{response.code}", request_id)
    end

    def retryable?(error)
      error.status == 503 || error.code == "concurrency_exceeded"
    end
  end

  # client.geocoding: the /geocoding/v1 endpoints.
  class GeocodingService
    def initialize(get)
      @get = get
    end

    # Find addresses and places matching free text. focus is {lat:, lon:}; country is an Array or a String.
    def search(q, focus: nil, country: nil, limit: nil, lang: nil)
      @get.call("/geocoding/v1/search", q: q, focus: focus, country: country, limit: limit, lang: lang)
    end

    # Suggest addresses and places as someone types.
    def autocomplete(q, focus: nil, country: nil, limit: nil, lang: nil)
      @get.call("/geocoding/v1/autocomplete", q: q, focus: focus, country: country, limit: limit, lang: lang)
    end

    # Find the address nearest a coordinate, or the area around it.
    def reverse(lat, lon, limit: nil, lang: nil)
      @get.call("/geocoding/v1/reverse", lat: lat, lon: lon, limit: limit, lang: lang)
    end
  end

  # client.places: the /places/v1 endpoints.
  class PlacesService
    def initialize(get)
      @get = get
    end

    # List places around a coordinate, optionally by category, an Array or a String.
    def nearby(lat, lon, category: nil, radius: nil, limit: nil, lang: nil)
      @get.call("/places/v1/nearby", lat: lat, lon: lon, category: category, radius: radius, limit: limit, lang: lang)
    end

    # Look up one place by its Mapricot ID.
    def get(id, lang: nil)
      @get.call("/places/v1/#{ERB::Util.url_encode(id)}", lang: lang)
    end
  end

  # client.routing: the /routing/v1 endpoints.
  class RoutingService
    def initialize(post)
      @post = post
    end

    # Find a route through 2 to 20 waypoints, each {lat:, lon:}. mode is "drive" (the default), "walk", or "bicycle".
    # geometries is "polyline" (the default), "polyline6", or "geojson".
    def route(waypoints, mode: nil, geometries: nil)
      @post.call("/routing/v1/route", { waypoints: waypoints, mode: mode, geometries: geometries })
    end

    # The areas reachable from a location, {lat:, lon:}, within 1 to 4 times, each 1 to 60 minutes, as a GeoJSON
    # FeatureCollection with one polygon per time, largest first. mode is as for route.
    def isochrone(location, minutes, mode: nil)
      @post.call("/routing/v1/isochrone", { location: location, minutes: minutes, mode: mode })
    end
  end

  # client.ip_geolocation: the /ip-geolocation/v1 endpoints.
  class IpGeolocationService
    def initialize(get)
      @get = get
    end

    # Approximate location of a public IP address.
    def lookup(ip)
      @get.call("/ip-geolocation/v1/#{ERB::Util.url_encode(ip)}")
    end
  end
end
