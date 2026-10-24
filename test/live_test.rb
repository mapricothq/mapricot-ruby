# frozen_string_literal: true

require "minitest/autorun"
require "mapricot/api"

class LiveTest < Minitest::Test
  def client
    skip "set MAPRICOT_KEY to run tests against the live API" if ENV["MAPRICOT_KEY"].to_s.empty?
    @client ||= Mapricot::Client.new
  end

  def test_search
    data = client.search("128 SW 3rd Ave, Portland", country: ["US"], limit: 1)
    assert_equal "Portland", data["results"][0]["address"]["locality"]
    refute_empty data["attribution"]
  end

  def test_autocomplete
    data = client.autocomplete("stumptown", focus: { lat: 45.52, lon: -122.68 }, limit: 1)
    assert_match(/Stumptown/, data["results"][0]["name"])
  end

  def test_reverse
    data = client.reverse(45.5217, -122.6733, limit: 1)
    assert_kind_of Integer, data["results"][0]["distanceMeters"]
  end

  def test_nearby
    data = client.nearby(45.52, -122.68, category: ["food:coffee_shop"], radius: 1000, limit: 1)
    assert_includes data["results"][0]["categories"], "food:coffee_shop"
  end

  def test_place
    found = client.search("Pioneer Courthouse Square, Portland", limit: 1)["results"][0]
    assert_equal found["id"], client.place(found["id"])["result"]["id"]
  end

  def test_route
    data = client.route([{ lat: 43.7396, lon: 7.4275 }, { lat: 43.734, lon: 7.4222 }], mode: "walk")
    assert_equal 1, data["routes"][0]["legs"].length
    refute_empty data["routes"][0]["polyline"]
  end

  def test_ip
    data = client.ip("8.8.8.8")
    assert data["found"]
    assert_equal "US", data["countryCode"]
  end

  def test_account
    assert_equal "active", client.account["status"]
  end

  def test_invalid_request
    error = assert_raises(Mapricot::Error) { client.search("") }
    assert_equal [400, "invalid_request"], [error.status, error.code]
    refute_nil error.request_id
  end

  def test_bad_key
    error = assert_raises(Mapricot::Error) { Mapricot::Client.new(api_key: "mapricot_sk_bad").account }
    assert_equal [401, "unauthorized"], [error.status, error.code]
  end
end
