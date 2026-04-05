require 'rails_helper'

RSpec.describe ShortLinkDecodeForm do
  describe 'validations' do
    it 'is valid with a short_url' do
      form = described_class.new(short_url: 'https://short.link/abc123')

      expect(form).to be_valid
    end

    it 'is invalid without a short_url' do
      form = described_class.new(short_url: nil)

      expect(form).not_to be_valid
      expect(form.errors[:short_url]).to include("can't be blank")
    end

    it 'is invalid with an empty string' do
      form = described_class.new(short_url: '')

      expect(form).not_to be_valid
    end
  end

  describe '#code' do
    it 'extracts the code from a short URL' do
      form = described_class.new(short_url: 'https://short.link/abc123')

      expect(form.code).to eq('abc123')
    end

    it 'extracts the code from a URL with nested path' do
      form = described_class.new(short_url: 'https://short.link/abc/def')

      expect(form.code).to eq('abc/def')
    end

    it 'handles whitespace in the URL' do
      form = described_class.new(short_url: '  https://short.link/abc123  ')

      expect(form.code).to eq('abc123')
    end

    it 'returns nil for an invalid URI' do
      form = described_class.new(short_url: 'ht tp://bad url')

      expect(form.code).to be_nil
    end

    it 'returns empty string when path is just /' do
      form = described_class.new(short_url: 'https://short.link/')

      expect(form.code).to eq('')
    end
  end
end
