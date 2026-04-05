REDIS_CONFIG = {
  url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
  pool_size: ENV.fetch('REDIS_POOL_SIZE', 10).to_i,
  pool_timeout: ENV.fetch('REDIS_POOL_TIMEOUT', 3).to_i
}.freeze

REDIS_POOL = ConnectionPool.new(size: REDIS_CONFIG[:pool_size], timeout: REDIS_CONFIG[:pool_timeout]) do
  Redis.new(url: REDIS_CONFIG[:url], driver: :hiredis)
end
