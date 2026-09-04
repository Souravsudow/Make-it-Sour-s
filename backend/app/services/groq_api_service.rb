class GroqApiService
  GROQ_API_BASE = 'https://api.groq.com/openai/v1/chat/completions'

  STAGE_CONFIGS = {
    reader: {
      key_env_names: %w[GROQ_API_KEY_READER GROQ_API_KEY_READER_2 GROQ_API_KEY_READER_3 GROQ_API_KEY_READER_4].freeze,
      # JSON mode is required for extraction; qwen3.8 is the JSON-capable model
      # available on this account (llama-3.x is no longer provisioned).
      default_models: %w[qwen/qwen3.8-27b].freeze,
      json_mode: true,
      max_tokens: 4000,
      temperature: 0.1
    },
    polisher: {
      key_env_names: %w[GROQ_API_KEY_POLISHER GROQ_API_KEY_POLISHER_2 GROQ_API_KEY_POLISHER_3].freeze,
      default_models: %w[qwen/qwen3.8-27b].freeze,
      json_mode: true,
      max_tokens: 6000,
      temperature: 0.3
    },
    latex: {
      key_env_names: %w[GROQ_API_KEY_LATEX GROQ_API_KEY_LATEX_2 GROQ_API_KEY_LATEX_3].freeze,
      default_models: %w[openai/gpt-oss-120b qwen/qwen3.8-27b].freeze,
      json_mode: false,
      max_tokens: 4000,
      temperature: 0.2
    }
  }.freeze

  RETRYABLE_STATUSES = [429, 500, 502, 503, 504].freeze
  KEY_ROTATE_STATUSES = [401, 403, 429].freeze

  attr_reader :api_keys

  def initialize(stage, request_id = nil)
    @stage = stage
    @config = STAGE_CONFIGS[stage] || raise("Unknown Groq stage: #{stage}")
    @request_id = request_id

    @api_keys = @config[:key_env_names].filter_map { |key_name| ENV[key_name].presence }

    # Fallback: if no stage-specific keys, try a single GROQ_API_KEY
    if @api_keys.empty?
      single_key = ENV['GROQ_API_KEY']
      @api_keys = [single_key] if single_key.present?
    end

    if @api_keys.empty?
      raise "No API keys found for Groq #{stage} stage. Set GROQ_API_KEY_#{stage.to_s.upcase} or GROQ_API_KEY"
    end
  end

  def make_request(prompt, json_mode: @config[:json_mode])
    messages = [{ role: 'user', content: prompt }]
    response = nil
    last_error = nil

    @api_keys.each_with_index do |api_key, key_index|
      models.each do |model|
        request_body = {
          model: model,
          messages: messages,
          max_tokens: @config[:max_tokens],
          temperature: @config[:temperature]
        }

        # Enable JSON mode for structured outputs (reader + polisher stages)
        if json_mode
          request_body[:response_format] = { type: 'json_object' }
        end

        begin
          resp = RestClient.post(
            GROQ_API_BASE,
            request_body.to_json,
            {
              'Content-Type' => 'application/json',
              'Authorization' => "Bearer #{api_key}",
              'Accept' => 'application/json'
            }
          )
          response = parse_response(resp)
          break
        rescue RestClient::ExceptionWithResponse => e
          last_error = e

          if key_rotation_error?(e)
            Rails.logger.warn("Groq #{@stage}: Key ##{key_index + 1} failed, trying next key: #{extract_error(e)}")
            break # Try next key
          end

          if retryable_error?(e)
            Rails.logger.warn("Groq #{@stage}: Model #{model} retryable error: #{extract_error(e)}")
            next # Try next model
          end

          raise handle_api_error(e)
        end
      end

      break if response
    end

    if response.nil?
      raise last_error ? handle_api_error(last_error) : "Groq #{@stage}: No response from any key/model"
    end

    response
  rescue RestClient::ExceptionWithResponse => e
    raise handle_api_error(e)
  end

  private

  def models
    configured = ENV["GROQ_MODEL_#{@stage.to_s.upcase}"]
    if configured.present?
      [configured] + @config[:default_models]
    else
      @config[:default_models]
    end
  end

  def parse_response(response)
    parsed = JSON.parse(response.body)
    if parsed['choices'].nil? || parsed['choices'].empty?
      raise "Empty response from Groq #{@stage}"
    end

    content = parsed.dig('choices', 0, 'message', 'content') || ''
    clean_output(content)
  end

  def clean_output(text)
    text = text.to_s.strip
    # Remove any markdown code fences the model might add
    text = text.sub(/\A```(?:json|latex|tex)?\s*/i, '')
    text = text.sub(/```\s*\z/, '')
    text.strip
  end

  def key_rotation_error?(error)
    return true if KEY_ROTATE_STATUSES.include?(error.response&.code)
    extract_error(error).match?(/api key|quota|rate limit|billing|exceeded|insufficient|invalid key/i)
  end

  def retryable_error?(error)
    return true if RETRYABLE_STATUSES.include?(error.response&.code)
    extract_error(error).match?(/high demand|overloaded|temporar|try again|unavailable/i)
  end

  def extract_error(error)
    return error.message unless error.response

    begin
      body = JSON.parse(error.response.body)
      body.dig('error', 'message') || body.to_s
    rescue JSON::ParserError
      error.response.body || error.message
    end
  end

  def handle_api_error(error)
    message = extract_error(error)

    case error.response&.code
    when 401
      "Groq #{@stage}: Invalid API key — check your GROQ_API_KEY_#{@stage.to_s.upcase}"
    when 429
      "Groq #{@stage}: Rate limit exceeded — try again shortly"
    when 400
      "Groq #{@stage}: Bad request — #{message}"
    else
      "Groq #{@stage} API error: #{message}"
    end
  end
end
