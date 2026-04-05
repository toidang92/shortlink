require 'rails_helper'

RSpec.describe Url, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      url = described_class.new(original_url: 'https://example.com', short_code: 'abc123')
      expect(url).to be_valid
    end

    it 'is invalid without original_url' do
      url = described_class.new(original_url: nil, short_code: 'abc123')
      expect(url).not_to be_valid
      expect(url.errors[:original_url]).to include("can't be blank")
    end

    it 'is invalid without short_code' do
      url = described_class.new(original_url: 'https://example.com', short_code: nil)
      expect(url).not_to be_valid
      expect(url.errors[:short_code]).to include("can't be blank")
    end

    it 'is invalid with original_url longer than 2048 characters' do
      url = described_class.new(original_url: "https://example.com/#{'a' * 2048}", short_code: 'abc123')
      expect(url).not_to be_valid
      expect(url.errors[:original_url]).to include('is too long (maximum is 2048 characters)')
    end

    it 'is invalid with short_code longer than 10 characters' do
      url = described_class.new(original_url: 'https://example.com', short_code: 'a' * 11)
      expect(url).not_to be_valid
      expect(url.errors[:short_code]).to include('is too long (maximum is 10 characters)')
    end

    it 'is invalid with duplicate short_code' do
      described_class.create!(original_url: 'https://example.com', short_code: 'abc123')
      url = described_class.new(original_url: 'https://other.com', short_code: 'abc123')
      expect(url).not_to be_valid
      expect(url.errors[:short_code]).to include('has already been taken')
    end
  end
end
