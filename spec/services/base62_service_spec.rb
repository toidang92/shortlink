require 'rails_helper'

RSpec.describe Base62Service do
  describe '.encode and .decode' do
    it 'round-trips an ID correctly' do
      id = 123_456
      encoded = described_class.encode(id)
      decoded = described_class.decode(encoded)

      expect(decoded).to eq(id)
    end

    it 'returns an 11-character string' do
      expect(described_class.encode(1).length).to eq(11)
      expect(described_class.encode(999_999).length).to eq(11)
    end

    it 'produces different codes for different IDs' do
      code1 = described_class.encode(1)
      code2 = described_class.encode(2)

      expect(code1).not_to eq(code2)
    end

    it 'produces non-sequential codes (obfuscated)' do
      code1 = described_class.encode(1)
      code2 = described_class.encode(2)
      code3 = described_class.encode(3)

      # Codes should not be alphabetically sequential
      sorted = [code1, code2, code3].sort
      expect(sorted).not_to eq([code1, code2, code3])
    end

    it 'only contains valid Base62 characters' do
      code = described_class.encode(42)

      expect(code).to match(/\A[0-9a-zA-Z]+\z/)
    end
  end
end
