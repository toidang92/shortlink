require 'rails_helper'

RSpec.describe 'Rate Limiting' do
  before do
    Rack::Attack.enabled = true
    Rack::Attack.reset!
  end

  after do
    Rack::Attack.reset!
  end

  describe 'global throttle (60 req/min per IP)' do
    it 'allows requests under the limit' do
      get '/up'
      expect(response).not_to have_http_status(:too_many_requests)
    end

    it 'returns 429 after exceeding 60 requests per minute' do
      61.times { get '/up' }

      expect(response).to have_http_status(:too_many_requests)
    end

    it 'includes rate limit headers in 429 response' do
      61.times { get '/up' }

      expect(response.headers['RateLimit-Limit']).to eq('60')
      expect(response.headers['RateLimit-Remaining']).to eq('0')
      expect(response.headers['RateLimit-Reset']).to be_present
    end

    it 'returns JSON error body' do
      61.times { get '/up' }

      expect(response.parsed_body['error']).to eq('Rate limit exceeded. Retry later.')
    end
  end

  describe 'encode throttle (10 req/min per IP)' do
    it 'returns 429 after exceeding 10 encode requests per minute' do
      11.times { post '/encode', params: { url: 'https://example.com' } }

      expect(response).to have_http_status(:too_many_requests)
    end

    it 'does not count non-encode requests toward encode limit' do
      9.times { post '/encode', params: { url: 'https://example.com' } }
      get '/up'
      post '/encode', params: { url: 'https://example.com' }

      expect(response).not_to have_http_status(:too_many_requests)
    end
  end
end
