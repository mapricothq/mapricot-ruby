# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "socket"
require "mapricot/api"

class RetryTest < Minitest::Test
  # Answers each request with the next failure, then with 200.
  def serve(failures)
    server = TCPServer.new("127.0.0.1", 0)
    seen = []
    thread = Thread.new do
      loop do
        socket = server.accept
        seen << socket.gets.split[1]
        while (line = socket.gets) && line != "\r\n"; end
        status, code = failures.shift || [200, nil]
        body = status == 200 ? '{"ok":true}' : JSON.generate(error: { code: code, message: code }, requestId: "r1")
        socket.write("HTTP/1.1 #{status} X\r\nContent-Type: application/json\r\nX-Request-Id: r1\r\n" \
                     "Content-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}")
        socket.close
      end
    end
    [Mapricot::Client.new(api_key: "k", base_url: "http://127.0.0.1:#{server.addr[1]}"), seen, -> { thread.kill; server.close }]
  end

  def test_retries_503_and_concurrency_exceeded
    client, seen, stop = serve([[503, "origin_overloaded"], [429, "concurrency_exceeded"]])
    assert_equal({ "ok" => true }, client.geocoding.search("x", focus: { lat: 1, lon: 2 }, country: %w[US CA]))
    assert_equal 3, seen.length
    assert_equal "/geocoding/v1/search?q=x&focus=1%2C2&country=US%2CCA", seen[0]
  ensure
    stop&.call
  end

  def test_does_not_retry_credit_exhausted
    client, seen, stop = serve([[429, "credit_exhausted"]])
    error = assert_raises(Mapricot::Error) { client.account }
    assert_equal [429, "credit_exhausted", "r1"], [error.status, error.code, error.request_id]
    assert_equal 1, seen.length
  ensure
    stop&.call
  end
end
