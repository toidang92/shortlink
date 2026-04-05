class UrlsController < ApplicationController
  MAX_URL_LENGTH = 2048

  def encode
    url = params[:url]

    return render json: { error: 'Invalid URL' }, status: :bad_request unless valid_url?(url)

    record = ShortenerService.encode(url)

    render json: { short_url: "#{request.base_url}/#{record.short_code}" }
  end

  def decode
    short_url = params[:short_url]
    code = extract_code(short_url)

    record = ShortenerService.decode(code)

    if record
      render json: { url: record.original_url }
    else
      render json: { error: 'Not found' }, status: :not_found
    end
  end

  private

  def valid_url?(url)
    return false if url.blank? || url.length > MAX_URL_LENGTH

    uri = URI.parse(url)
    %w[http https].include?(uri.scheme)
  rescue URI::InvalidURIError
    false
  end

  def extract_code(short_url)
    URI.parse(short_url.to_s).path.delete_prefix('/')
  rescue URI::InvalidURIError
    nil
  end
end
