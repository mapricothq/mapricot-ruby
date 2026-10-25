# Mapricot for Ruby

The official Ruby client for the [Mapricot API](https://mapricot.com/): address and place search, reverse geocoding, nearby places, routing, and IP geolocation, with 250,000 free requests every month.

```sh
gem install mapricot-api
```

It needs Ruby 3.1 or later and has no dependencies outside the standard library.

## Quick start

Create a server key in the [dashboard](https://app.mapricot.com/) and pass it to the client. Keep it out of your source code, for example by reading it from an environment variable as here.

```ruby
require "mapricot/api"

client = Mapricot::Client.new(api_key: ENV.fetch("MAPRICOT_KEY"))

data = client.search("128 SW 3rd Ave, Portland", limit: 1)
place = data["results"][0]
puts place["label"], place["lat"], place["lon"]
```

## Methods

Each method returns the API's JSON as a Hash with string keys, with the same field names as the [API reference](https://mapricot.com/api-reference/).

| Method | Endpoint |
| --- | --- |
| `client.search(q, focus:, country:, limit:, lang:)` | [`GET /geocoding/v1/search`](https://mapricot.com/docs/geocoding/#find-an-address) |
| `client.autocomplete(q, focus:, country:, limit:, lang:)` | [`GET /geocoding/v1/autocomplete`](https://mapricot.com/docs/geocoding/#suggest-as-people-type) |
| `client.reverse(lat, lon, limit:, lang:)` | [`GET /geocoding/v1/reverse`](https://mapricot.com/docs/geocoding/#find-the-address-at-a-point) |
| `client.nearby(lat, lon, category:, radius:, limit:, lang:)` | [`GET /places/v1/nearby`](https://mapricot.com/docs/places/#list-places-around-a-point) |
| `client.place(id, lang:)` | [`GET /places/v1/{id}`](https://mapricot.com/docs/places/#look-up-a-saved-place) |
| `client.route(waypoints, mode:, geometries:)` | [`POST /routing/v1/route`](https://mapricot.com/docs/routing/#get-a-route) |
| `client.isochrone(location, minutes, mode:)` | [`POST /routing/v1/isochrone`](https://mapricot.com/docs/routing/#get-an-isochrone) |
| `client.ip(address)` | [`GET /ip-geolocation/v1/{ip}`](https://mapricot.com/docs/ip-geolocation/#look-up-an-address) |
| `client.account` | `GET /account`, which checks a key and is never billed |

Every keyword argument is optional. `focus` and each waypoint are `{ lat:, lon: }`. `country` and `category` take an Array or a comma-separated String.

```ruby
nearby = client.nearby(45.52, -122.68, category: ["food:coffee_shop"], radius: 1000)
route = client.route([{ lat: 45.5189, lon: -122.6793 }, { lat: 45.5214, lon: -122.6828 }], mode: "walk")
puts route["routes"][0]["durationSeconds"]
```

A route's path comes as an encoded `polyline` with five decimal places, which polyline decoders assume. Pass `geometries: "geojson"` to get it as a GeoJSON `LineString` in `geometry` instead, which maps draw without decoding, or `geometries: "polyline6"` for six decimal places.

An isochrone is a GeoJSON `FeatureCollection` with one polygon per time, largest first, so a map that draws them in order shows the smaller ones on top:

```ruby
area = client.isochrone({ lat: 45.5189, lon: -122.6793 }, [5, 10], mode: "walk")
puts area["features"].map { |feature| feature["properties"]["minutes"] }.inspect
```

If your app shows results, show the credits in each response's `attribution`.

## Errors and retries

An error response raises `Mapricot::Error`, with the HTTP `status`, the API's error `code`, a `message`, and the `request_id`:

```ruby
begin
  client.search("")
rescue Mapricot::Error => e
  puts e.status, e.code, e.message # 400, invalid_request, The service rejected the request.
end
```

The client retries `503` responses and `429 concurrency_exceeded`, up to twice, waiting longer each time. Errors aren't billed. Pass `max_retries:` and `timeout:` (seconds) to `Mapricot::Client.new` to change this. The [API reference](https://mapricot.com/api-reference/#errors) lists every status.

## Links

- [Mapricot](https://mapricot.com/)
- [Ruby docs](https://mapricot.com/docs/ruby/)
- [API reference](https://mapricot.com/api-reference/)
- [Pricing](https://mapricot.com/pricing/)
