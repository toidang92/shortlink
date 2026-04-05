class ShortLinkEncodeForm
  include ActiveModel::Model

  attr_accessor :url

  validates :url, presence: true, length: { maximum: AppConstants::MAX_URL_LENGTH }
  validate :valid_url_format

  def initialize(attributes = {})
    super
    @url = attributes[:url].to_s.strip
  end

  def normalized_url
    return nil unless valid?

    uri = URI.parse(url.strip)
    uri.normalize.to_s
  end

  private

  def valid_url_format
    uri = URI.parse(url.to_s.strip)

    errors.add(:url, 'must be http or https') unless %w[http https].include?(uri.scheme)
  rescue URI::InvalidURIError
    errors.add(:url, 'is invalid')
  end
end
