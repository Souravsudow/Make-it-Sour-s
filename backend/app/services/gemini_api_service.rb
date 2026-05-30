class GeminiApiService < ResumeApiService
  GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions'
  DEFAULT_MODELS = %w[
    gemini-2.5-flash
    gemini-2.5-flash-lite
    gemini-2.0-flash
    gemini-2.0-flash-lite
  ].freeze
  API_KEY_NAMES = %w[
    GEMINI_API_KEY
    GEMINI_API_KEY_2
    GEMINI_API_KEY_3
    GEMINI_API_KEY_4
  ].freeze
  
  def initialize(request_id = nil)
    super(request_id)
    @api_keys = API_KEY_NAMES.filter_map { |key_name| ENV[key_name].presence }
    raise 'GEMINI_API_KEY not set in environment' if @api_keys.empty?
  end

  private

  def make_api_request(prompt, pre_message = nil)
    messages = [{
      role: 'user',
      content: prompt
    }]

    response = nil
    last_error = nil

    @api_keys.each_with_index do |api_key, key_index|
      gemini_models.each do |model|
        request_body = {
          model: model,
          max_tokens: 8192,
          messages: messages,
          temperature: 0.2,
          response_format: response_format_for(prompt)
        }.compact

        begin
          response = RestClient.post(
            GEMINI_API_URL,
            request_body.to_json,
            {
              'Accept' => 'application/json',
              'Content-Type' => 'application/json',
              'Authorization' => "Bearer #{api_key}"
            }
          )
          break
        rescue RestClient::ExceptionWithResponse => e
          last_error = e

          if rotate_api_key_error?(e)
            Rails.logger.warn("Gemini API key ##{key_index + 1} failed, trying next key: #{extract_response_error(e)}")
            break
          end

          raise unless retryable_api_error?(e)

          Rails.logger.warn("Gemini model #{model} failed with retryable error: #{extract_response_error(e)}")
        end
      end

      break if response
    end

    handle_api_error(last_error) if response.nil? && last_error
    raise 'Empty response from Gemini API' if response.nil?
    
    parsed_response = JSON.parse(response.body)
    raise "Empty response from Gemini API" if parsed_response['choices'].nil? || parsed_response['choices'].empty?

    choices = parsed_response['choices']
    first_choice = choices.is_a?(Array) ? choices[0] : choices
    message = first_choice.is_a?(Hash) ? first_choice['message'] : first_choice
    content = message.is_a?(Hash) ? message['content'] : message.to_s

    clean_model_output(content)
  rescue RestClient::ExceptionWithResponse => e
    handle_api_error(e)
  end

  def gemini_models
    configured_model = ENV['GEMINI_MODEL']
    return ([configured_model] + DEFAULT_MODELS).compact.uniq if configured_model.present?

    DEFAULT_MODELS
  end

  def retryable_api_error?(error)
    return true if [429, 500, 502, 503, 504].include?(error.response&.code)

    extract_response_error(error).match?(/high demand|overloaded|temporar|try again|quota|not found|not supported/i)
  end

  def rotate_api_key_error?(error)
    return true if [401, 403, 429].include?(error.response&.code)

    extract_response_error(error).match?(/api key|quota|rate limit|billing|exceeded your current quota|free tier/i)
  end

  def extract_response_error(error)
    return error.message unless error.response

    begin
      extract_error_message(JSON.parse(error.response.body))
    rescue JSON::ParserError
      error.response.body || error.message
    end
  end

  def response_format_for(prompt)
    prompt.include?('structured JSON format') ? { type: 'json_object' } : nil
  end

  def clean_model_output(content)
    text = content.to_s.strip
    text = text.sub(/\A```(?:json|latex|tex)?\s*/i, '')
    text = text.sub(/```\s*\z/, '')
    text.strip
  end

  def handle_api_error(error)
    error_message = if error.response
      begin
        error_body = JSON.parse(error.response.body)
        extract_error_message(error_body)
      rescue JSON::ParserError
        error.response.body || error.message
      end
    else
      error.message
    end

    case error.response&.code
    when 401 then raise 'Invalid API key'
    when 429 then raise 'Rate limit exceeded for Gemini API'
    else raise "Gemini API error: #{error_message}"
    end
  end

  def extract_error_message(error_body)
    case error_body
    when Hash
      error = error_body['error']
      return extract_error_message(error) if error

      error_body['message'] || error_body['detail'] || error_body.to_json
    when Array
      error_body.map { |item| extract_error_message(item) }.join(', ')
    else
      error_body.to_s
    end
  end
end 
