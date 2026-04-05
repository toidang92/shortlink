module Rack
  class Attack
    # Use Redis as the cache store with connection pool
    Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
      url: REDIS_CONFIG[:url],
      driver: :hiredis,
      pool_size: REDIS_CONFIG[:pool_size],
      pool_timeout: REDIS_CONFIG[:pool_timeout]
    )

    # Limit all requests to 60 per minute per IP
    throttle('req/ip', limit: 60, period: 1.minute, &:ip)

    # Limit encode requests to 10 per minute per IP
    throttle('encode/ip', limit: 10, period: 1.minute) do |req|
      req.ip if req.path == '/encode' && req.post?
    end

    # Return rate limit info in response headers
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
