class ShortLinksController < ApplicationController
  def encode
    form = ShortLinkEncodeForm.new(url: params[:url])

    return render_error('Invalid URL', :bad_request) unless form.valid?

    record = ShortenerService.encode(form.normalized_url)

    render json: {
      short_url: "#{request.base_url}/#{record.short_code}"
    }
  end

  def decode
    form = ShortLinkDecodeForm.new(short_url: params[:short_url])

    code = form.code

    return render_error('Not found', :not_found) if code.blank?

    record = ShortenerService.decode(code)

    if record
      render json: { url: record.original_url }
    else
      render_error('Not found', :not_found)
    end
  end

  private

  def render_error(message, status)
    render json: { error: message }, status: status
  end
end
