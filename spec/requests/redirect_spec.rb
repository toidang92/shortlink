require 'rails_helper'

RSpec.describe 'GET /:code', type: :request do
  it 'redirects to the original URL with 301' do
    record = Url.create!(original_url: 'https://example.com', short_code: 'rdr123')

    get "/#{record.short_code}"

    expect(response).to have_http_status(:moved_permanently)
    expect(response).to redirect_to('https://example.com')
  end

  it 'returns 404 for an unknown code' do
    get '/zzzzzz'

    expect(response).to have_http_status(:not_found)
    expect(response.parsed_body['error']).to eq('Not found')
  end

  it 'does not match codes with wrong format' do
    get '/too-long-code-with-dashes'

    expect(response).to have_http_status(:not_found)
  end
end
