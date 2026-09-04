# Be sure to restart your server when you modify this file.

# --- Redis-backed cache store for Rack::Attack ---
# Uses the existing $redis connection with a 'rate_limit:' key prefix
# to share the same Redis instance without collision.

class RateLimitStore
  PREFIX = 'rate_limit:'

  # Resolve the Redis client at call time, NOT boot time. This initializer
  # loads before config/initializers/redis.rb (alphabetical order), so $redis
  # is still nil when this class is constructed — capturing it then would make
  # every throttled request raise NoMethodError.
  def client
    $redis
  end

  def read(key)
    val = client.get(PREFIX + key.to_s)
    val.nil? ? nil : val.to_s
  end

  def write(key, value, options = {})
    full_key = PREFIX + key.to_s
    if options[:expires_in]
      client.setex(full_key, options[:expires_in].to_i, value.to_s)
    else
      client.set(full_key, value.to_s)
    end
  end

  def increment(key, count = 1, options = {})
    full_key = PREFIX + key.to_s
    new_val = client.incrby(full_key, count)
    client.expire(full_key, options[:expires_in].to_i) if options[:expires_in]
    new_val
  end

  def delete(key)
    client.del(PREFIX + key.to_s)
  end

  def clear
    # No-op: don't flush the shared Redis
  end
end

Rack::Attack.cache.store = RateLimitStore.new

# ---------- Throttles ----------

# Resume upload — most expensive (AI calls + thread spawn)
# 5 per minute per IP prevents abuse while allowing legit usage
Rack::Attack.throttle('uploads/ip', limit: 5, period: 1.minute) do |req|
  if req.post? && req.path.include?('/api/v1/resumes') && !req.path.include?('/preview')
    req.ip
  end
end

# PDF preview — moderately expensive (pdflatex compilation)
Rack::Attack.throttle('previews/ip', limit: 10, period: 1.minute) do |req|
  if req.get? && req.path.include?('/api/v1/resumes/preview')
    req.ip
  end
end

# SSE status polling — lightweight but can be noisy
Rack::Attack.throttle('status/ip', limit: 30, period: 1.minute) do |req|
  if req.get? && req.path.include?('/api/v1/status/events')
    req.ip
  end
end

# ---------- Safelists ----------

# Allow health check to always pass
Rack::Attack.safelist('health check') do |req|
  req.path == '/up' && req.get?
end

# ---------- Custom Response ----------

Rack::Attack.throttled_responder = lambda do |request|
  match_data = request.env['rack.attack.match_data']
  retry_after = match_data ? match_data[:period] : 60

  [
    429,
    {
      'Content-Type' => 'application/json',
      'Retry-After' => retry_after.to_s
    },
    [{
      error: 'Too many requests. Please slow down.',
      retry_after_seconds: retry_after
    }.to_json]
  ]
end

# ---------- Logging ----------

ActiveSupport::Notifications.subscribe('rack_attack') do |_name, _start, _finish, _request_id, payload|
  req = payload[:request]
  Rails.logger.warn("[Rack::Attack] Throttled #{req.request_method} #{req.path} from IP #{req.ip}")
end
