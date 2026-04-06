require 'rails_helper'

RSpec.describe ShortenerService do
  describe '.encode' do
    it 'creates a persisted ShortLink record' do
      record = described_class.encode('https://example.com')

      expect(record).to be_a(ShortLink)
      expect(record).to be_persisted
    end

    it 'stores the original URL and generates a valid short code' do
      record = described_class.encode('https://example.com')

      expect(record.original_url).to eq('https://example.com')
      expect(record.short_code).to match(/\A[a-zA-Z0-9]{#{AppConstants::MIN_CODE_LENGTH},#{AppConstants::MAX_CODE_LENGTH}}\z/o)
    end

    it 'generates unique codes for different URLs' do
      record1 = described_class.encode('https://example.com/1')
      record2 = described_class.encode('https://example.com/2')

      expect(record1.short_code).not_to eq(record2.short_code)
    end

    it 'generates deterministic code based on record ID' do
      record = described_class.encode('https://example.com')
      expected_code = Base62Service.encode(record.id)

      expect(record.short_code).to eq(expected_code)
    end
  end

  describe '.decode' do
    it 'returns the ShortLink record for a valid code' do
      record = described_class.encode('https://example.com')
      found = described_class.decode(record.short_code)

      expect(found).to eq(record)
    end

    it 'returns nil for an unknown code' do
      expect(described_class.decode('zzzzzz')).to be_nil
    end

    it 'returns nil for nil input' do
      expect(described_class.decode(nil)).to be_nil
    end

    it 'returns nil for code shorter than minimum length' do
      expect(described_class.decode('abc')).to be_nil
    end
  end
end
