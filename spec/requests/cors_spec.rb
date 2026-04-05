require 'rails_helper'

RSpec.describe 'CORS', type: :request do
  it 'returns CORS headers for an OPTIONS preflight request' do
    options '/encode', headers: {
      'Origin' => 'http://example.com',
      'Access-Control-Request-Method' => 'POST',
      'Access-Control-Request-Headers' => 'Content-Type'
    }

    expect(response).to have_http_status(:ok)
    expect(response.headers['Access-Control-Allow-Origin']).to eq('*')
    expect(response.headers['Access-Control-Allow-Methods']).to include('GET', 'POST')
    expect(response.headers['Access-Control-Allow-Methods']).not_to include('PUT', 'DELETE', 'PATCH')
    expect(response.headers['Access-Control-Allow-Headers']).to include('Content-Type')
  end

  it 'returns CORS headers on a regular POST request' do
    post '/encode', params: { url: 'https://example.com' },
                    headers: { 'Origin' => 'http://example.com' }

    expect(response.headers['Access-Control-Allow-Origin']).to eq('*')
  end

  it 'returns CORS headers on a GET request' do
    get '/up', headers: { 'Origin' => 'http://example.com' }

    expect(response.headers['Access-Control-Allow-Origin']).to eq('*')
  end

  it 'allows any origin' do
    post '/encode', params: { url: 'https://example.com' },
                    headers: { 'Origin' => 'http://other-domain.org' }

    expect(response.headers['Access-Control-Allow-Origin']).to eq('*')
  end
end
