# Publishes status updates to Redis (persistent) + Pub/Sub (real-time).
# The SSE controller subscribes to Pub/Sub for instant delivery,
# while Redis acts as a fallback for late-connecting SSE clients.
class StatusPublisher
  CHANNEL_PREFIX = 'resume:'

  class << self
    # Publish a status update.
    # +data+ should be a Hash like { status: "message" } or { status: "message", result: { latex: "..." } }
    def publish(request_id, data)
      publish_to_redis(request_id, data)
      publish_to_pubsub(request_id, data)
    rescue StandardError => e
      Rails.logger.error("[StatusPublisher #{request_id}] Failed: #{e.message}")
    end

    private

    STATUS_TTL = 3600 # 1 hour

    def publish_to_redis(request_id, data)
      status_key = "resume_status:#{request_id}"
      $redis.set(status_key, data[:status])
      $redis.expire(status_key, STATUS_TTL)

      if data[:result]
        result_key = "resume_result:#{request_id}"
        $redis.set(result_key, data[:result].to_json)
        $redis.expire(result_key, STATUS_TTL)
      end

      # Store name separately for PDF file naming
      if data[:name]
        $redis.set("resume_name:#{request_id}", data[:name].to_json)
        $redis.expire("resume_name:#{request_id}", STATUS_TTL)
      end
    end

    def publish_to_pubsub(request_id, data)
      channel = "#{CHANNEL_PREFIX}#{request_id}"
      $redis.publish(channel, data.to_json)
    end
  end
end
