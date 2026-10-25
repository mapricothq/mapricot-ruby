# frozen_string_literal: true

require "minitest/autorun"
require "mapricot/api"

class LiveTest < Minitest::Test
  def client
    skip "set MAPRICOT_KEY to run tests against the live API" if ENV["MAPRICOT_KEY"].to_s.empty?
    @client ||= Mapricot::Client.new(api_key: ENV["MAPRICOT_KEY"])
  end

  def test_search
    data = client.geocoding.search("128 SW 3rd Ave, Portland", country: ["US"], limit: 1)
    assert_equal "Portland", data["results"][0]["address"]["locality"]
    refute_empty data["attribution"]
  end

  def test_autocomplete
    data = client.geocoding.autocomplete("stumptown", focus: { lat: 45.52, lon: -122.68 }, limit: 1)
    assert_match(/Stumptown/, data["results"][0]["name"])
  end

  def test_reverse
    data = client.geocoding.reverse(45.5217, -122.6733, limit: 1)
    assert_kind_of Integer, data["results"][0]["distanceMeters"]
  end

  def test_nearby
    data = client.places.nearby(45.52, -122.68, category: ["food:coffee_shop"], radius: 1000, limit: 1)
    assert_includes data["results"][0]["categories"], "food:coffee_shop"
  end

  def test_place
    found = client.geocoding.search("Pioneer Courthouse Square, Portland", limit: 1)["results"][0]
    assert_equal found["id"], client.places.get(found["id"])["result"]["id"]
  end

  def test_route
    data = client.routing.route([{ lat: 43.7396, lon: 7.4275 }, { lat: 43.734, lon: 7.4222 }], mode: "walk")
    assert_equal 1, data["routes"][0]["legs"].length
    refute_empty data["routes"][0]["polyline"]
    refute_empty data["routes"][0]["legs"][0]["steps"].last["instruction"]
  end

  def test_route_steps_in_french
    data = client.routing.route([{ lat: 43.7396, lon: 7.4275 }, { lat: 43.734, lon: 7.4222 }], lang: "fr")
    assert_includes data["routes"][0]["legs"][0]["steps"].last["instruction"], "destination"
  end

  def test_isochrone
    data = client.routing.isochrone({ lat: 43.7396, lon: 7.4275 }, [5, 10], mode: "walk")
    assert_equal [10, 5], data["features"].map { |feature| feature["properties"]["minutes"] }
    assert_equal "Polygon", data["features"][0]["geometry"]["type"]
    refute_empty data["attribution"]
  end

  def test_route_geojson
    data = client.routing.route([{ lat: 43.7396, lon: 7.4275 }, { lat: 43.734, lon: 7.4222 }], geometries: "geojson")
    assert_equal "LineString", data["routes"][0]["geometry"]["type"]
    assert_operator data["routes"][0]["geometry"]["coordinates"].length, :>, 1
  end

  def test_ip
    data = client.ip_geolocation.lookup("8.8.8.8")
    assert data["found"]
    assert_equal "US", data["countryCode"]
  end

  def test_account
    assert_equal "active", client.account["status"]
  end

  def test_invalid_request
    error = assert_raises(Mapricot::Error) { client.geocoding.search("") }
    assert_equal [400, "invalid_request"], [error.status, error.code]
    refute_nil error.request_id
  end

  def test_bad_key
    error = assert_raises(Mapricot::Error) { Mapricot::Client.new(api_key: "mapricot_sk_bad").account }
    assert_equal [401, "unauthorized"], [error.status, error.code]
  end
end
