require 'rails_helper'

RSpec.describe GroqApiService do
  let(:groq_url) { 'https://api.groq.com/openai/v1/chat/completions' }

  before do
    WebMock.disable_net_connect!(allow: [/redis/])
  end

  after do
    WebMock.allow_net_connect!
  end

  describe 'initialization' do
    it 'raises an error if no API keys are configured' do
      ClimateControl.modify(
        'GROQ_API_KEY_READER' => nil,
        'GROQ_API_KEY' => nil
      ) do
        expect { described_class.new(:reader) }
          .to raise_error(/No API keys found for Groq reader/)
      end
    end

    it 'falls back to GROQ_API_KEY when stage-specific keys are missing' do
      ClimateControl.modify(
        'GROQ_API_KEY_READER' => nil,
        'GROQ_API_KEY' => 'fallback-key'
      ) do
        service = described_class.new(:reader)
        expect(service.send(:api_keys)).to include('fallback-key')
      end
    end

    it 'uses stage-specific keys when available' do
      ClimateControl.modify('GROQ_API_KEY_READER' => 'reader-key-1') do
        service = described_class.new(:reader)
        expect(service.send(:api_keys)).to include('reader-key-1')
      end
    end

    it 'raises for unknown stage' do
      expect { described_class.new(:unknown) }.to raise_error(/Unknown Groq stage/)
    end
  end

  describe '#make_request' do
    let(:service) do
      ClimateControl.modify('GROQ_API_KEY_READER' => 'test-reader-key') do
        described_class.new(:reader, 'test-123')
      end
    end

    context 'with JSON mode' do
      it 'sends a valid request to the Groq API and parses the JSON response' do
        stub_request(:post, groq_url)
          .with(
            headers: { 'Authorization' => 'Bearer test-reader-key' },
            body: hash_including(
              model: 'llama-3.1-8b-instant',
              messages: [{ role: 'user', content: 'Extract resume data' }],
              response_format: { type: 'json_object' }
            )
          )
          .to_return(
            status: 200,
            headers: { 'Content-Type' => 'application/json' },
            body: {
              choices: [{ message: { content: '{"name":"John"}' } }]
            }.to_json
          )

        result = service.make_request('Extract resume data', json_mode: true)
        expect(result).to eq('{"name":"John"}')
      end
    end

    context 'with text mode' do
      it 'does not send response_format in the request body' do
        stub_request(:post, groq_url)
          .with(headers: { 'Authorization' => 'Bearer test-reader-key' })
          .to_return(
            status: 200,
            headers: { 'Content-Type' => 'application/json' },
            body: {
              choices: [{ message: { content: '\documentclass{article}' } }]
            }.to_json
          )

        result = service.make_request('Generate LaTeX', json_mode: false)
        expect(result).to eq('\documentclass{article}')

        # Verify that response_format was NOT in the request body
        expect(WebMock).to have_requested(:post, groq_url)
          .with { |req| !JSON.parse(req.body).key?('response_format') }
      end
    end

    it 'strips markdown code fences from the response' do
      stub_request(:post, groq_url)
        .to_return(
          status: 200,
          headers: { 'Content-Type' => 'application/json' },
          body: {
            choices: [{ message: { content: "```json\n{\"key\":\"value\"}\n```" } }]
          }.to_json
        )

      result = service.make_request('test', json_mode: true)
      expect(result).to eq('{"key":"value"}')
    end

    it 'raises on empty response from API' do
      stub_request(:post, groq_url)
        .to_return(
          status: 200,
          headers: { 'Content-Type' => 'application/json' },
          body: { choices: [] }.to_json
        )

      expect { service.make_request('test') }
        .to raise_error(/Empty response from Groq reader/)
    end

    context 'key rotation' do
      let(:multi_key_service) do
        ClimateControl.modify(
          'GROQ_API_KEY_READER' => 'bad-key',
          'GROQ_API_KEY_READER_2' => 'good-key'
        ) do
          described_class.new(:reader, 'test-123')
        end
      end

      it 'rotates to the next key on 401' do
        stub_request(:post, groq_url)
          .with(headers: { 'Authorization' => 'Bearer bad-key' })
          .to_return(status: 401, body: { error: { message: 'Invalid' } }.to_json)

        stub_request(:post, groq_url)
          .with(headers: { 'Authorization' => 'Bearer good-key' })
          .to_return(
            status: 200,
            headers: { 'Content-Type' => 'application/json' },
            body: { choices: [{ message: { content: 'success' } }] }.to_json
          )

        result = multi_key_service.make_request('test')
        expect(result).to eq('success')
      end

      it 'rotates to the next key on 429' do
        stub_request(:post, groq_url)
          .with(headers: { 'Authorization' => 'Bearer bad-key' })
          .to_return(status: 429, body: { error: { message: 'Rate limited' } }.to_json)

        stub_request(:post, groq_url)
          .with(headers: { 'Authorization' => 'Bearer good-key' })
          .to_return(
            status: 200,
            headers: { 'Content-Type' => 'application/json' },
            body: { choices: [{ message: { content: 'success' } }] }.to_json
          )

        result = multi_key_service.make_request('test')
        expect(result).to eq('success')
      end
    end

    context 'model retry' do
      it 'tries the next model on a 5xx error and succeeds' do
        stub_request(:post, groq_url)
          .to_return(
            { status: 502, body: { error: { message: 'Bad Gateway' } }.to_json },
            { status: 200, headers: { 'Content-Type' => 'application/json' },
              body: { choices: [{ message: { content: 'recovered' } }] }.to_json }
          )

        result = service.make_request('test')
        expect(result).to eq('recovered')
      end
    end

    context 'when all keys and models fail' do
      it 'raises a descriptive error message' do
        stub_request(:post, groq_url)
          .to_return(status: 401, body: { error: { message: 'Unauthorized' } }.to_json)

        expect { service.make_request('test') }
          .to raise_error(/Groq reader: Invalid API key/)
      end
    end

    context 'polisher stage' do
      it 'uses the polisher model and key' do
        polisher = ClimateControl.modify('GROQ_API_KEY_POLISHER' => 'polish-key') do
          described_class.new(:polisher)
        end

        stub_request(:post, groq_url)
          .with(
            headers: { 'Authorization' => 'Bearer polish-key' },
            body: hash_including(model: 'llama-3.3-70b-versatile')
          )
          .to_return(
            status: 200,
            headers: { 'Content-Type' => 'application/json' },
            body: { choices: [{ message: { content: 'polished' } }] }.to_json
          )

        result = polisher.make_request('Polish this', json_mode: true)
        expect(result).to eq('polished')
      end
    end

    context 'latex stage' do
      it 'uses the latex model and does not set json mode' do
        latex_gen = ClimateControl.modify('GROQ_API_KEY_LATEX' => 'latex-key') do
          described_class.new(:latex)
        end

        stub_request(:post, groq_url)
          .with(headers: { 'Authorization' => 'Bearer latex-key' })
          .to_return(
            status: 200,
            headers: { 'Content-Type' => 'application/json' },
            body: { choices: [{ message: { content: '\LaTeX code' } }] }.to_json
          )

        result = latex_gen.make_request('Generate LaTeX', json_mode: false)
        expect(result).to eq('\LaTeX code')

        # Verify no response_format in request body
        expect(WebMock).to have_requested(:post, groq_url)
          .with { |req| !JSON.parse(req.body).key?('response_format') }
      end
    end
  end

  describe 'private methods' do
    let(:service) do
      ClimateControl.modify('GROQ_API_KEY_READER' => 'test-reader-key') do
        described_class.new(:reader, 'test-123')
      end
    end

    describe 'clean_output' do
      it 'removes json markdown fences' do
        input = "```json\n{\"a\":1}\n```"
        result = service.send(:clean_output, input)
        expect(result).to eq('{"a":1}')
      end

      it 'removes latex markdown fences' do
        input = "```latex\n\\documentclass{article}\n```"
        result = service.send(:clean_output, input)
        expect(result).to eq('\\documentclass{article}')
      end

      it 'does not modify clean text' do
        result = service.send(:clean_output, 'Hello world')
        expect(result).to eq('Hello world')
      end
    end
  end
end
