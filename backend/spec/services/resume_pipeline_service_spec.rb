require 'rails_helper'

RSpec.describe ResumePipelineService do
  let(:request_id) { 'pipeline-test-123' }
  let(:redis) { instance_double(Redis) }

  # Sample resume text
  let(:resume_text) do
    "John Doe\njohn@email.com\nSoftware Engineer at Google\nBuilt scalable systems"
  end

  # What the reader stage should extract
  let(:extracted_json) do
    {
      'name' => { 'first_name' => 'John', 'last_name' => 'Doe' },
      'contact_info' => { 'email' => 'john@email.com' },
      'education' => [],
      'experience' => [
        { 'title' => 'Software Engineer', 'company' => 'Google',
          'dates' => '2020-2023', 'bullets' => ['Built scalable systems'] }
      ],
      'projects' => [],
      'technical_skills' => { 'Languages' => ['Python'] },
      'honors' => []
    }
  end

  # What the polisher stage should return (improved version)
  let(:polished_json) do
    {
      'name' => { 'first_name' => 'John', 'last_name' => 'Doe' },
      'contact_info' => { 'email' => 'john@email.com' },
      'education' => [],
      'experience' => [
        { 'title' => 'Software Engineer', 'company' => 'Google',
          'dates' => '2020-2023',
          'bullets' => ['Engineered scalable distributed systems handling 1M+ users'] }
      ],
      'projects' => [],
      'technical_skills' => { 'Languages' => ['Python', 'SQL'] },
      'honors' => []
    }
  end

  let(:latex_output) { "\\documentclass{article}\n\\begin{document}\nJohn Doe Resume\n\\end{document}" }

  before do
    # Stub Redis with custom expectations
    $redis = redis
    allow(redis).to receive(:set)
    allow(redis).to receive(:get)
    allow(redis).to receive(:expire)
    allow(redis).to receive(:del)
    allow(redis).to receive(:publish)  # StatusPublisher uses publish
  end

  # Set dummy Groq API keys so the pipeline constructor doesn't fail
  around(:each) do |example|
    ClimateControl.modify(
      'GROQ_API_KEY_READER' => 'test-reader',
      'GROQ_API_KEY_POLISHER' => 'test-polisher',
      'GROQ_API_KEY_LATEX' => 'test-latex'
    ) do
      example.run
    end
  end

  describe '#format_resume' do
    it 'completes the full 3-stage pipeline and returns LaTeX' do
      # Mock the 3 GroqApiService instances
      reader = instance_double(GroqApiService)
      polisher = instance_double(GroqApiService)
      latex_gen = instance_double(GroqApiService)

      allow(GroqApiService).to receive(:new).with(:reader, request_id).and_return(reader)
      allow(GroqApiService).to receive(:new).with(:polisher, request_id).and_return(polisher)
      allow(GroqApiService).to receive(:new).with(:latex, request_id).and_return(latex_gen)

      # Reader returns extracted JSON
      expect(reader).to receive(:make_request)
        .with(an_instance_of(String), json_mode: true)
        .and_return(extracted_json.to_json)

      # Polisher receives normalized data and returns polished JSON
      expect(polisher).to receive(:make_request)
        .with(an_instance_of(String), json_mode: true)
        .and_return(polished_json.to_json)

      # Latex generator receives polished data and returns LaTeX
      expect(latex_gen).to receive(:make_request)
        .with(an_instance_of(String), json_mode: false)
        .and_return(latex_output)

      # Redis status updates should be called multiple times
      expect(redis).to receive(:set).with("resume_status:#{request_id}", /Starting resume/)
      expect(redis).to receive(:set).with("resume_status:#{request_id}", /Reading/)
      expect(redis).to receive(:set).with("resume_status:#{request_id}", /Polishing/)
      expect(redis).to receive(:set).with("resume_status:#{request_id}", /Generating/)
      expect(redis).to receive(:set).with("resume_status:#{request_id}", /completed/)

      # Name should be stored in Redis
      expect(redis).to receive(:set).with("resume_name:#{request_id}", extracted_json['name'].to_json)
      expect(redis).to receive(:expire).with("resume_name:#{request_id}", 3600)

      service = described_class.new(request_id)
      result = service.format_resume(resume_text)

      expect(result).to eq(latex_output)
    end

    it 'validates word count and raises for resumes over 2000 words' do
      long_text = (['word'] * 2500).join(' ')

      service = described_class.new(request_id)
      expect { service.format_resume(long_text) }
        .to raise_error(/Resume is too long/)
    end

    it 'raises error if reader returns an error object' do
      reader = instance_double(GroqApiService)
      polisher = instance_double(GroqApiService)
      latex_gen = instance_double(GroqApiService)

      allow(GroqApiService).to receive(:new).with(:reader, request_id).and_return(reader)
      allow(GroqApiService).to receive(:new).with(:polisher, request_id).and_return(polisher)
      allow(GroqApiService).to receive(:new).with(:latex, request_id).and_return(latex_gen)

      expect(reader).to receive(:make_request)
        .and_return({ 'error' => 'Not a resume' }.to_json)

      service = described_class.new(request_id)
      expect { service.format_resume(resume_text) }
        .to raise_error(/Not a resume/)
    end

    it 'gracefully falls back to original data if polishing JSON parse fails' do
      reader = instance_double(GroqApiService)
      polisher = instance_double(GroqApiService)
      latex_gen = instance_double(GroqApiService)

      allow(GroqApiService).to receive(:new).with(:reader, request_id).and_return(reader)
      allow(GroqApiService).to receive(:new).with(:polisher, request_id).and_return(polisher)
      allow(GroqApiService).to receive(:new).with(:latex, request_id).and_return(latex_gen)

      expect(reader).to receive(:make_request).and_return(extracted_json.to_json)
      # Polisher returns invalid JSON
      expect(polisher).to receive(:make_request).and_return("not valid json{{{")
      # LaTeX generator should still receive valid data (the original)
      expect(latex_gen).to receive(:make_request) do |prompt, json_mode: false|
        expect(prompt).to include('Software Engineer')
        latex_output
      end

      expect(redis).to receive(:set).at_least(:once)

      service = described_class.new(request_id)
      result = service.format_resume(resume_text)
      expect(result).to eq(latex_output)
    end

    it 'uses the request_id passed to constructor' do
      service = described_class.new(request_id)
      expect(service.instance_variable_get(:@request_id)).to eq(request_id)
    end

    it 'generates its own request_id if none provided' do
      allow(SecureRandom).to receive(:uuid).and_return('auto-generated-id')

      service = described_class.new
      expect(service.instance_variable_get(:@request_id)).to eq('auto-generated-id')
    end
  end
end
