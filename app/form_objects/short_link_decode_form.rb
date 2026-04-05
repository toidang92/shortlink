class ShortLinkDecodeForm
  include ActiveModel::Model

  attr_accessor :short_url

  validates :short_url, presence: true

  def code
    uri = URI.parse(short_url.to_s.strip)
    uri.path.delete_prefix('/')
  rescue URI::InvalidURIError
    nil
  end
end
