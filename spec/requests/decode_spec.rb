require 'rails_helper'

RSpec.describe 'POST /decode', type: :request do
  it 'returns the original URL for a valid short URL' do
    record = Url.create!(original_url: 'https://example.com', short_code: 'abc123')

    post '/decode', params: { short_url: "http://localhost/#{record.short_code}" }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['url']).to eq('https://example.com')
  end

  it 'returns 404 for an unknown short URL' do
    post '/decode', params: { short_url: 'http://localhost/zzzzzz' }

    expect(response).to have_http_status(:not_found)
    expect(response.parsed_body['error']).to eq('Not found')
  end

  it 'handles a full encode-then-decode flow' do
    post '/encode', params: { url: 'https://example.com/full-flow' }
    short_url = response.parsed_body['short_url']

    post '/decode', params: { short_url: short_url }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['url']).to eq('https://example.com/full-flow')
  end
end
