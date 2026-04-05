class Url < ApplicationRecord
  validates :original_url, presence: true, length: { maximum: 2048 }
  validates :short_code, presence: true, uniqueness: true, length: { maximum: 10 }
end
