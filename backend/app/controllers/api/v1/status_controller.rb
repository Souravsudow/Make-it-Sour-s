module Api
  module V1
    class StatusController < ApplicationController
      include ActionController::Live

      def events
        request_id = params[:request_id]
        channel = "resume:#{request_id}"
        timeout = ENV.fetch('SSE_TIMEOUT_SECONDS', 180).to_i
        status_key = "resume_status:#{request_id}"
        result_key = "resume_result:#{request_id}"

        Rails.logger.info("[SSE #{request_id}] Starting connection")
        response.headers['Content-Type'] = 'text/event-stream'
        response.headers['Cache-Control'] = 'no-cache'

        sse = SSE.new(response.stream, retry: 3000)
        message_received = false

        # Fast path: if the job already finished before this SSE connection
        # opened (fast failure, or a reconnect after completion), deliver the
        # final status immediately instead of blocking on Pub/Sub for the
        # full timeout window.
        current_status = $redis.get(status_key)
        if current_status&.include?('completed') || current_status&.include?('Error')
          Rails.logger.info("[SSE #{request_id}] Job already finished; delivering final status")
          result = $redis.get(result_key)
          sse.write(result ? { status: current_status, result: JSON.parse(result) } : { status: current_status })
          $redis.del(status_key)
          $redis.expire(result_key, 3600) if result
          return
        end

        # Subscribe to Redis Pub/Sub for real-time status updates.
        # Uses a dedicated connection so we don't block the shared $redis.
        subscriber = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))

        begin
          subscriber.subscribe_with_timeout(timeout, channel) do |on|
            on.message do |_ch, msg|
              data = JSON.parse(msg)
              sse.write(data)
              message_received = true

              # Stop listening on completion or error
              if data['status']&.include?('completed') || data['status']&.include?('Error')
                subscriber.unsubscribe(channel)
                break
              end
            end
          end
        rescue Redis::TimeoutError
          Rails.logger.warn("[SSE #{request_id}] Pub/Sub timed out after #{timeout}s")
        rescue Redis::BaseConnectionError => e
          Rails.logger.error("[SSE #{request_id}] Pub/Sub connection error: #{e.message}")
        rescue JSON::ParserError => e
          Rails.logger.error("[SSE #{request_id}] Invalid Pub/Sub message: #{e.message}")
        rescue IOError, ClientDisconnected
          # Client disconnected — normal
        rescue StandardError => e
          Rails.logger.error("[SSE #{request_id}] Pub/Sub error: #{e.message}")
        ensure
          subscriber.close rescue nil
        end

        # Fallback: if no Pub/Sub message arrived (job already completed
        # before we subscribed), check Redis for the current result.
        unless message_received
          Rails.logger.info("[SSE #{request_id}] Checking Redis fallback")
          status = $redis.get(status_key)
          if status
            if status.include?('completed')
              result = $redis.get(result_key)
              sse.write(result ? { status: status, result: JSON.parse(result) } : { status: status })
            else
              sse.write({ status: status })
            end
          end
        end

        # Cleanup completed status
        if $redis.get(status_key)&.include?('completed')
          $redis.del(status_key)
          $redis.expire(result_key, 3600)
        end
      rescue IOError, ClientDisconnected
        # Client disconnected
      rescue StandardError => e
        Rails.logger.error("[SSE #{request_id}] SSE error: #{e.message}")
      ensure
        sse.close rescue nil
        response.stream.close rescue nil
        Rails.logger.info("[SSE #{request_id}] Connection closed")
      end
    end
  end
end
