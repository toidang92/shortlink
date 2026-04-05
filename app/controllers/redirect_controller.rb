class RedirectController < ApplicationController
  def show
    record = ShortenerService.decode(params[:code])

    if record
      redirect_to record.original_url, status: :moved_permanently, allow_other_host: true
    else
      render json: { error: 'Not found' }, status: :not_found
    end
  end
end
