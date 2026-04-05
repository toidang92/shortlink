require 'rails_helper'

RSpec.describe 'POST /encode' do
  it 'returns a short URL for a valid URL' do
    post '/encode', params: { url: 'https://example.com' }

    expect(response).to have_http_status(:ok)

    body = response.parsed_body
    expect(body['short_url']).to match(%r{\Ahttp://www.example.com/[a-zA-Z0-9]{6,}\z})
  end

  it 'persists the URL in the database' do
    expect do
      post '/encode', params: { url: 'https://example.com' }
    end.to change(ShortLink, :count).by(1)
  end

  it 'returns 400 for a missing URL' do
    post '/encode', params: {}

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body['error']).to eq('Invalid URL')
  end

  it 'returns 400 for an invalid URL' do
    post '/encode', params: { url: 'not-a-url' }

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body['error']).to eq('Invalid URL')
  end

  it 'returns 400 for a URL without http/https scheme' do
    post '/encode', params: { url: 'ftp://example.com' }

    expect(response).to have_http_status(:bad_request)
  end

  it 'returns 400 for a URL exceeding 2048 characters' do
    long_url = "https://example.com/#{'a' * 2048}"
    post '/encode', params: { url: long_url }

    expect(response).to have_http_status(:bad_request)
  end
end
