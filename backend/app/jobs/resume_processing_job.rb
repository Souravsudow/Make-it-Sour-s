class ResumeProcessingJob < ApplicationJob
  queue_as :default

  # Let Sidekiq handle retries (3 attempts) — this allows exceptions to propagate
  # normally in tests using perform_now, while Sidekiq manages retries in production
  sidekiq_options retry: 3

  def perform(content:, content_type:, original_filename:, request_id:, template: 'jakes')
    Rails.logger.info("[ResumeProcessingJob #{request_id}] Started processing")

    latex_content = ResumeFormatterService.new(
      content: content,
      content_type: content_type,
      original_filename: original_filename,
      request_id: request_id,
      template: template
    ).format

    StatusPublisher.publish(request_id, {
      status: "Resume formatting completed successfully!",
      result: { latex: latex_content }
    })

    Rails.logger.info("[ResumeProcessingJob #{request_id}] Completed successfully")
  rescue StandardError => e
    Rails.logger.error("[ResumeProcessingJob #{request_id}] Error: #{e.message}")
    StatusPublisher.publish(request_id, { status: "Error: #{e.message}" })
    raise # Let Sidekiq handle retries
  end
end
