# frozen_string_literal: true

require_relative "lib/mapricot/api"

Gem::Specification.new do |spec|
  spec.name = "mapricot-api"
  spec.version = Mapricot::VERSION
  spec.authors = ["Mapricot"]
  spec.summary = "Official client for the Mapricot API: geocoding, places, routing, and IP geolocation."
  spec.homepage = "https://mapricot.com/"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"
  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE"]
  spec.metadata = {
    "documentation_uri" => "https://mapricot.com/docs/ruby/",
    "source_code_uri" => "https://github.com/mapricothq/mapricot-ruby",
    "bug_tracker_uri" => "https://github.com/mapricothq/mapricot-ruby/issues",
    "rubygems_mfa_required" => "true"
  }
end
