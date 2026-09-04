require 'rails_helper'

RSpec.describe ResumeProcessingJob do
  let(:request_id) { 'job-test-123' }
  let(:content) { "John Doe's resume text content" }
  let(:content_type) { 'text/plain' }
  let(:original_filename) { 'resume.txt' }

  before do
    # Stub Redis
    $redis = instance_double(Redis, get: nil, set: true, expire: true, del: true)
    allow($redis).to receive(:set)
    allow($redis).to receive(:publish)  # StatusPublisher uses publish
  end

  describe '#perform' do
    it 'processes a resume through the pipeline and stores the result' do
      formatter = instance_double(ResumeFormatterService)
      allow(ResumeFormatterService).to receive(:new)
        .with(content: content, content_type: content_type, original_filename: original_filename, request_id: request_id, template: 'jakes')
        .and_return(formatter)

      expect(formatter).to receive(:format).and_return('\\documentclass{article}')

      # Should set status updates
      expect($redis).to receive(:set).with("resume_status:#{request_id}", "Resume formatting completed successfully!")
      expect($redis).to receive(:set).with("resume_result:#{request_id}", { latex: '\\documentclass{article}' }.to_json)

      # Status/result keys should get a TTL so Redis doesn't leak
      expect($redis).to receive(:expire).with("resume_status:#{request_id}", 3600)
      expect($redis).to receive(:expire).with("resume_result:#{request_id}", 3600)

      described_class.perform_now(
        content: content,
        content_type: content_type,
        original_filename: original_filename,
        request_id: request_id
      )
    end

    it 'passes the selected template through to the formatter' do
      formatter = instance_double(ResumeFormatterService)
      allow(ResumeFormatterService).to receive(:new)
        .with(content: content, content_type: content_type, original_filename: original_filename, request_id: request_id, template: 'modern')
        .and_return(formatter)
      allow(formatter).to receive(:format).and_return('\\documentclass{article}')

      described_class.perform_now(
        content: content,
        content_type: content_type,
        original_filename: original_filename,
        request_id: request_id,
        template: 'modern'
      )
    end

    it 'stores error in Redis and re-raises on failure' do
      formatter = instance_double(ResumeFormatterService)
      allow(ResumeFormatterService).to receive(:new).and_return(formatter)
      allow(formatter).to receive(:format).and_raise(RuntimeError.new('AI service unavailable'))

      expect($redis).to receive(:set).with("resume_status:#{request_id}", "Error: AI service unavailable")

      expect do
        described_class.perform_now(
          content: content,
          content_type: content_type,
          original_filename: original_filename,
          request_id: request_id
        )
      end.to raise_error(RuntimeError, 'AI service unavailable')
    end
  end
end
