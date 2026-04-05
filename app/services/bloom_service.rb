class BloomService
  KEY = 'shortlink:bloom'.freeze

  def self.might_exist?(code)
    REDIS_POOL.with { |redis| redis.call('BF.EXISTS', KEY, code) == 1 }
  rescue RedisClient::Error, ConnectionPool::TimeoutError => e
    Rails.logger.warn("BloomService.might_exist? failed: #{e.message}, falling back to DB")
    Url.exists?(short_code: code)
  end

  def self.add(code)
    REDIS_POOL.with { |redis| redis.call('BF.ADD', KEY, code) }
  rescue RedisClient::Error, ConnectionPool::TimeoutError => e
    Rails.logger.warn("BloomService.add failed: #{e.message}, skipping bloom insert")
    nil
  end
end
