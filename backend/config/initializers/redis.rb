require 'connection_pool'

# A minimal thread-safe Redis facade. Every call checks out a connection from a
# shared pool, so multi-threaded contexts (Sidekiq workers, Rack::Attack inside
# Puma) never share a single connection between threads.
class ThreadSafeRedis
  def initialize(pool)
    @pool = pool
  end

  def method_missing(name, *args, **kwargs, &block)
    @pool.with { |redis| redis.public_send(name, *args, **kwargs, &block) }
  end

  def respond_to_missing?(_name, _include_private = false)
    true
  end
end

REDIS_POOL = ConnectionPool.new(
  size: Integer(ENV.fetch('REDIS_POOL_SIZE', 10)),
  timeout: 5
) do
  Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
end

# $redis is now a thread-safe wrapper around the pool, so every existing call
# site (controllers, services, Rack::Attack store) works unchanged.
$redis = ThreadSafeRedis.new(REDIS_POOL)