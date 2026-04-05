require 'rails_helper'

RSpec.describe ShortLink do
  describe 'validations' do
    let(:valid_code) { 'a' * AppConstants::MIN_CODE_LENGTH }

    it 'is valid with valid attributes' do
      url = described_class.new(original_url: 'https://example.com', short_code: valid_code)
      expect(url).to be_valid
    end

    it 'is invalid without original_url' do
      url = described_class.new(original_url: nil, short_code: valid_code)
      expect(url).not_to be_valid
      expect(url.errors[:original_url]).to include("can't be blank")
    end

    it 'is valid without short_code (auto-generated later)' do
      url = described_class.new(original_url: 'https://example.com', short_code: nil)
      expect(url).to be_valid
    end

    it 'is invalid with original_url longer than 2048 characters' do
      url = described_class.new(original_url: "https://example.com/#{'a' * 2048}", short_code: valid_code)
      expect(url).not_to be_valid
      expect(url.errors[:original_url]).to include('is too long (maximum is 2048 characters)')
    end

    it 'is invalid with short_code longer than max length' do
      long_code = 'a' * (AppConstants::MAX_CODE_LENGTH + 1)
      url = described_class.new(original_url: 'https://example.com', short_code: long_code)
      expect(url).not_to be_valid
      max = AppConstants::MAX_CODE_LENGTH
      expect(url.errors[:short_code]).to include("is too long (maximum is #{max} characters)")
    end

    it 'is invalid with short_code shorter than min length' do
      url = described_class.new(original_url: 'https://example.com', short_code: 'a')
      expect(url).not_to be_valid
      min = AppConstants::MIN_CODE_LENGTH
      expect(url.errors[:short_code]).to include("is too short (minimum is #{min} characters)")
    end

    it 'is invalid with duplicate short_code' do
      described_class.create!(original_url: 'https://example.com', short_code: valid_code)
      url = described_class.new(original_url: 'https://other.com', short_code: valid_code)
      expect(url).not_to be_valid
      expect(url.errors[:short_code]).to include('has already been taken')
    end
  end
end
