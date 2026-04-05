module Rack
  class Attack
    # Use Redis as the cache store with connection pool
    Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
      url: REDIS_CONFIG[:url],
      driver: :hiredis,
      pool: { size: REDIS_CONFIG[:pool_size], timeout: REDIS_CONFIG[:pool_timeout] }
    )

    # ---------------------------------------------------------------------------
    # Algorithm: Fixed Window Counter
    #
    # How it works:
    #   - Time is divided into fixed windows (e.g., 1-minute intervals)
    #   - Each window has a counter per IP, stored in Redis with TTL = window size
    #   - Key format: rack::attack:<epoch_time / period>:<rule>:<ip>
    #   - Counter increments on each request; if count > limit → 429
    #   - Counter auto-expires at end of window (Redis TTL)
    #
    # Example (60 req/min, window = 60s):
    #   12:00:00 - 12:00:59 → counter for this window (max 60)
    #   12:01:00 - 12:01:59 → new counter (reset to 0)
    #
    # Trade-off vs Sliding Window:
    #   - Simpler, fewer Redis operations (single INCR per request)
    #   - Edge case: user could send 60 req at 12:00:59 + 60 req at 12:01:00
    #     = 120 req in 2 seconds (burst at window boundary)
    #   - Acceptable for this use case; stricter control would need sliding window log
    # ---------------------------------------------------------------------------

    # Limit all requests to 60 per minute per IP
    throttle('req/ip', limit: 60, period: 1.minute, &:ip)

    # Limit encode requests to 10 per minute per IP (stricter to prevent DB flooding)
    throttle('encode/ip', limit: 10, period: 1.minute) do |req|
      req.ip if req.path == '/encode' && req.post?
    end

    # Return rate limit info in response headers (RFC 6585 style)
    self.throttled_responder = lambda do |request|
      match_data = request.env['rack.attack.match_data']
      now = match_data[:epoch_time]

      headers = {
        'RateLimit-Limit' => match_data[:limit].to_s,
        'RateLimit-Remaining' => '0',
        'RateLimit-Reset' => (now + (match_data[:period] - (now % match_data[:period]))).to_s,
        'Content-Type' => 'application/json'
      }

      [429, headers, [{ error: 'Rate limit exceeded. Retry later.' }.to_json]]
    end
  end
end
