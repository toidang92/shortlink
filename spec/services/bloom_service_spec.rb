require 'rails_helper'

RSpec.describe BloomService do
  describe '.add and .might_exist?' do
    it 'returns false for a code not in the filter' do
      expect(described_class.might_exist?("nothere_#{SecureRandom.hex(4)}")).to be false
    end

    it 'returns true after adding a code' do
      code = "bloom_#{SecureRandom.hex(4)}"
      described_class.add(code)
      expect(described_class.might_exist?(code)).to be true
    end
  end

  describe 'Redis fallback' do
    it 'falls back to DB lookup when Redis is down on might_exist?' do
      allow(REDIS_POOL).to receive(:with).and_raise(RedisClient::ConnectionError, 'connection refused')
      Url.create!(original_url: 'https://example.com', short_code: 'fallbk')

      expect(described_class.might_exist?('fallbk')).to be true
      expect(described_class.might_exist?('nope99')).to be false
    end

    it 'returns nil and logs warning when Redis is down on add' do
      allow(REDIS_POOL).to receive(:with).and_raise(RedisClient::ConnectionError, 'connection refused')
      allow(Rails.logger).to receive(:warn)

      expect(described_class.add('anycode')).to be_nil
      expect(Rails.logger).to have_received(:warn).with(/BloomService.add failed/)
    end
  end
end
