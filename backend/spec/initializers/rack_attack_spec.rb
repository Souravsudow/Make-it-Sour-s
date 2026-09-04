require 'rails_helper'

RSpec.describe 'Rack::Attack rate limiting' do
  let(:app) { ->(env) { [200, { 'Content-Type' => 'text/plain' }, ['OK']] } }
  let(:middleware) { Rack::Attack.new(app) }

  def env_for(path, method: 'GET', ip: '1.2.3.4')
    Rack::MockRequest.env_for(path, method: method, 'REMOTE_ADDR' => ip)
  end

  def call_rack_attack(path, method: 'GET', ip: '1.2.3.4')
    middleware.call(env_for(path, method: method, ip: ip))
  end

  def status(path, method: 'GET', ip: '1.2.3.4')
    call_rack_attack(path, method: method, ip: ip).first
  end

  before do
    Rack::Attack.enabled = true
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.cache.store.clear
  end

  after do
    Rack::Attack.enabled = false
    Rack::Attack.cache.store.clear
  end

  describe 'throttle uploads/ip' do
    it 'allows 5 POST requests per minute per IP' do
      5.times { expect(status('/api/v1/resumes', method: 'POST')).not_to eq(429) }
    end

    it 'blocks the 6th POST request from the same IP' do
      5.times { call_rack_attack('/api/v1/resumes', method: 'POST') }
      expect(status('/api/v1/resumes', method: 'POST')).to eq(429)
    end

    it 'allows a different IP to upload freely' do
      5.times { call_rack_attack('/api/v1/resumes', method: 'POST', ip: '1.2.3.4') }
      expect(status('/api/v1/resumes', method: 'POST', ip: '5.6.7.8')).not_to eq(429)
    end

    it 'does not throttle GET requests to /api/v1/resumes' do
      10.times { expect(status('/api/v1/resumes')).not_to eq(429) }
    end

    it 'does not throttle POST to preview path' do
      10.times { expect(status('/api/v1/resumes/preview', method: 'POST')).not_to eq(429) }
    end
  end

  describe 'throttle previews/ip' do
    it 'allows 10 preview requests per minute per IP' do
      10.times { expect(status('/api/v1/resumes/preview?request_id=test', method: 'GET')).not_to eq(429) }
    end

    it 'blocks the 11th preview request from the same IP' do
      10.times { call_rack_attack('/api/v1/resumes/preview?request_id=test', method: 'GET') }
      expect(status('/api/v1/resumes/preview?request_id=test', method: 'GET')).to eq(429)
    end
  end

  describe 'throttle status/ip' do
    it 'allows 30 status requests per minute per IP' do
      30.times { expect(status('/api/v1/status/events?request_id=test', method: 'GET')).not_to eq(429) }
    end

    it 'blocks the 31st status request' do
      30.times { call_rack_attack('/api/v1/status/events?request_id=test', method: 'GET') }
      expect(status('/api/v1/status/events?request_id=test', method: 'GET')).to eq(429)
    end
  end

  describe 'safelist health check' do
    it 'allows unlimited health check requests' do
      100.times { expect(status('/up', method: 'GET')).not_to eq(429) }
    end
  end

  describe 'throttled response format' do
    it 'returns JSON with retry_after_seconds' do
      5.times { call_rack_attack('/api/v1/resumes', method: 'POST') }

      response = call_rack_attack('/api/v1/resumes', method: 'POST')
      expect(response[0]).to eq(429)
      expect(response[1]['Content-Type']).to include('application/json')
      expect(response[1]['Retry-After']).to be_present

      body_text = response[2].respond_to?(:each) ? response[2].each.first : response[2]
      parsed = JSON.parse(body_text.to_s)
      expect(parsed['error']).to match(/Too many requests/)
      expect(parsed['retry_after_seconds']).to be_a(Integer)
    end
  end
end
