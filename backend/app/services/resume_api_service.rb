class ResumeApiService
  def initialize(request_id = nil)
    @request_id = request_id || SecureRandom.uuid
  end

  def format_resume(resume_content)
    update_status("Starting resume formatting process...")
    Rails.logger.info("Starting resume formatting process...")
    Rails.logger.info("Resume content length: #{resume_content.length} characters")

    validate_word_count!(resume_content)

    update_status("Extracting structured information from resume...")
    Rails.logger.info("Step 1: Extracting structured information...")
    extracted_info = extract_resume_details(resume_content)

    update_status("Normalizing and validating extracted data...")
    Rails.logger.info("Step 2: Normalizing and validating extracted data...")
    normalized = ResumeDataNormalizer.normalize(extracted_info)
    ResumeDataNormalizer.validate!(normalized)

    update_status("Rendering resume as LaTeX...")
    Rails.logger.info("Step 3: Rendering resume as LaTeX...")
    latex = ResumeLatexRenderer.new(normalized).render

    update_status("Resume formatting completed successfully!")
    Rails.logger.info("Resume formatting completed successfully")
    latex
  rescue ResumeDataNormalizer::ValidationError => e
    Rails.logger.error("Validation error: #{e.message}")
    update_status("Error: Invalid resume data extracted - #{e.message}")
    raise "Failed to process resume: #{e.message}"
  rescue StandardError => e
    Rails.logger.error("API error: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    update_status("Error: #{e.message}")
    raise "Failed to process resume: #{e.message}"
  end

  protected

  def validate_word_count!(content)
    word_count = content.split(/\s+/).count
    Rails.logger.info("Resume word count: #{word_count}")
    if word_count > 2000
      error_message = "Resume is too long (#{word_count} words)."
      Rails.logger.error(error_message)
      raise error_message
    end
  end

  def extract_resume_details(resume_content)
    Rails.logger.info("Making API request for resume extraction...")
    response = make_api_request(extraction_prompt(resume_content))
    parsed_json = JSON.parse(extract_json(response))
    if parsed_json['error']
      Rails.logger.error("Error in extraction response: #{parsed_json['error']}")
      raise parsed_json['error']
    end

    if parsed_json['name']
      $redis.set("resume_name:#{@request_id}", parsed_json['name'].to_json)
      $redis.expire("resume_name:#{@request_id}", 3600)
      Rails.logger.info("Stored name in Redis: #{parsed_json['name'].to_json}")
    end

    Rails.logger.info("Successfully parsed JSON response")
    parsed_json
  rescue JSON::ParserError => e
    Rails.logger.error("JSON parsing error: #{e.message}")
    Rails.logger.error("Failed response content:")
    Rails.logger.error(response)
    raise "Failed to extract resume details: #{e.message}"
  end

  def extract_json(response)
    text = response.to_s.strip
    text = text.sub(/\A```(?:json)?\s*/i, '')
    text = text.sub(/```\s*\z/, '')

    start_index = text.index('{')
    end_index = text.rindex('}')
    raise JSON::ParserError, 'No JSON object found in model response' unless start_index && end_index && end_index >= start_index

    text[start_index..end_index]
  end

  def extraction_prompt(resume_content)
    ResumePrompts.extraction_prompt(resume_content)
  end

  def update_status(message)
    Rails.logger.info("Updating status: #{message}")
    status_key = "resume_status:#{@request_id}"
    Rails.logger.info("Status key: #{status_key}")
    begin
      $redis.set(status_key, message)
      Rails.logger.info("Status updated successfully")
    rescue StandardError => e
      Rails.logger.error("Failed to update status in Redis: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
    end
  end

  def make_api_request(prompt)
    raise NotImplementedError, "Child classes must implement make_api_request"
  end
end