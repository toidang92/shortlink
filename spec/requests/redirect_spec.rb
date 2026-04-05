require 'rails_helper'

RSpec.describe 'GET /:code' do
  it 'redirects to the original URL with 301' do
    record = ShortenerService.encode('https://example.com')

    get "/#{record.short_code}"

    expect(response).to have_http_status(:moved_permanently)
    expect(response).to redirect_to('https://example.com')
  end

  it 'returns 404 for an unknown code' do
    get '/zzzzzzzzzzz'

    expect(response).to have_http_status(:not_found)
    expect(response.parsed_body['error']).to eq('Not found')
  end

  it 'does not match codes with wrong format' do
    get '/too-long-code-with-dashes'

    expect(response).to have_http_status(:not_found)
  end
end
