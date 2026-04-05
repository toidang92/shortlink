class ShortLink < ApplicationRecord
  before_validation :strip_attributes

  validates :original_url, presence: true, length: { maximum: 2048 }
  validates :short_code, uniqueness: true, length: { minimum: AppConstants::MIN_CODE_LENGTH, maximum: AppConstants::MAX_CODE_LENGTH }, allow_nil: true, format: { with: /\A[a-zA-Z0-9]*\z/ }

  private

  def strip_attributes
    self.original_url = original_url&.strip
    self.short_code = short_code&.strip
  end
end
