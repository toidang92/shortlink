require 'rails_helper'

RSpec.describe ShortLinkEncodeForm do
  describe 'validations' do
    it 'is valid with a valid http URL' do
      form = described_class.new(url: 'http://example.com')

      expect(form).to be_valid
    end

    it 'is valid with a valid https URL' do
      form = described_class.new(url: 'https://example.com/path?query=1')

      expect(form).to be_valid
    end

    it 'is invalid without a URL' do
      form = described_class.new(url: nil)

      expect(form).not_to be_valid
      expect(form.errors[:url]).to include("can't be blank")
    end

    it 'is invalid with an empty string' do
      form = described_class.new(url: '')

      expect(form).not_to be_valid
    end

    it 'is invalid with a non-http scheme' do
      form = described_class.new(url: 'ftp://example.com')

      expect(form).not_to be_valid
      expect(form.errors[:url]).to include('must be http or https')
    end

    it 'is invalid with no scheme' do
      form = described_class.new(url: 'example.com')

      expect(form).not_to be_valid
      expect(form.errors[:url]).to include('must be http or https')
    end

    it 'is invalid with an invalid URI' do
      form = described_class.new(url: 'ht tp://bad url')

      expect(form).not_to be_valid
      expect(form.errors[:url]).to include('is invalid')
    end

    it "is invalid when URL exceeds #{AppConstants::MAX_URL_LENGTH} characters" do
      long_url = "https://example.com/#{'a' * AppConstants::MAX_URL_LENGTH}"
      form = described_class.new(url: long_url)

      expect(form).not_to be_valid
      expect(form.errors[:url]).to include(/is too long/)
    end
  end

  describe '#normalized_url' do
    it 'returns the normalized URL when valid' do
      form = described_class.new(url: 'https://example.com/path')

      expect(form.normalized_url).to eq('https://example.com/path')
    end

    it 'strips whitespace from the URL' do
      form = described_class.new(url: '  https://example.com  ')

      expect(form.normalized_url).to eq('https://example.com/')
    end

    it 'returns nil when the form is invalid' do
      form = described_class.new(url: nil)

      expect(form.normalized_url).to be_nil
    end
  end
end
