class ResumePipelineService
  def initialize(request_id = nil, template: 'jakes')
    @request_id = request_id || SecureRandom.uuid
    @template = template
    @reader = GroqApiService.new(:reader, @request_id)
    @polisher = GroqApiService.new(:polisher, @request_id)
    @latex_gen = GroqApiService.new(:latex, @request_id)
  end

  # Main entry point — runs the full 3-stage Groq pipeline
  def format_resume(resume_content)
    update_status("Starting resume transformation with Groq AI...")
    Rails.logger.info("ResumePipeline [#{@request_id}]: Content length = #{resume_content.length} chars")

    validate_word_count!(resume_content)

    # ── Stage 1: READER — extract structured JSON from raw text ──
    update_status("Reading and extracting structured data from your resume...")
    extracted = extract_resume_data(resume_content)
    normalized = normalize_data(extracted)

    # ── Stage 2: POLISHER — improve bullet points, add impact ──
    update_status("Polishing and strengthening your resume content...")
    polished = polish_resume(normalized)

    # ── Stage 3: LATEX — generate LaTeX code from polished data ──
    update_status("Generating professional LaTeX resume...")
    latex = generate_latex(polished)

    update_status("Resume transformation completed successfully!")
    Rails.logger.info("ResumePipeline [#{@request_id}]: Completed successfully")
    latex

  rescue ResumeDataNormalizer::ValidationError => e
    Rails.logger.error("ResumePipeline [#{@request_id}]: Validation error: #{e.message}")
    update_status("Error: Invalid resume data extracted - #{e.message}")
    raise "Failed to process resume: #{e.message}"
  rescue StandardError => e
    Rails.logger.error("ResumePipeline [#{@request_id}]: #{e.class}: #{e.message}")
    Rails.logger.error(e.backtrace.first(5).join("\n")) if e.backtrace
    update_status("Error: #{e.message}")
    raise "Failed to process resume: #{e.message}"
  end

  private

  # ── Stage 1 Implementation ──

  def extract_resume_data(resume_content)
    prompt = ResumePrompts.extraction_prompt(resume_content)
    response = @reader.make_request(prompt, json_mode: true)
    parsed = JSON.parse(response)

    if parsed['error']
      raise parsed['error']
    end

    # Store name via publisher for PDF file naming
    if parsed['name']
      StatusPublisher.publish(@request_id, {
        status: "Extracted name: #{parsed['name']['first_name']} #{parsed['name']['last_name']}",
        name: parsed['name']
      })
    end

    Rails.logger.info("ResumePipeline [#{@request_id}]: Extraction successful")
    parsed

  rescue JSON::ParserError => e
    Rails.logger.error("ResumePipeline [#{@request_id}]: JSON parse error in extraction: #{e.message}")
    Rails.logger.error("ResumePipeline [#{@request_id}]: Raw response: #{response}")
    raise "Failed to extract resume details: #{e.message}"
  end

  def normalize_data(raw)
    normalized = ResumeDataNormalizer.normalize(raw)
    ResumeDataNormalizer.validate!(normalized)
    normalized
  end

  # ── Stage 2 Implementation ──

  def polish_resume(data)
    prompt = ResumePrompts.polishing_prompt(data)
    response = @polisher.make_request(prompt, json_mode: true)
    polished = JSON.parse(response)

    ResumeDataNormalizer.validate!(polished)
    Rails.logger.info("ResumePipeline [#{@request_id}]: Polishing successful")
    polished

  rescue JSON::ParserError => e
    Rails.logger.warn("ResumePipeline [#{@request_id}]: Polishing JSON parse error, using original: #{e.message}")
    data
  rescue ResumeDataNormalizer::ValidationError => e
    Rails.logger.warn("ResumePipeline [#{@request_id}]: Polishing validation error, using original: #{e.message}")
    data
  end

  # ── Stage 3 Implementation ──

  def generate_latex(data)
    prompt = ResumePrompts.latex_prompt(data.to_json, template: @template)
    @latex_gen.make_request(prompt, json_mode: false)
  end

  # ── Helpers ──

  def validate_word_count!(content)
    word_count = content.split(/\s+/).count
    Rails.logger.info("ResumePipeline [#{@request_id}]: Word count = #{word_count}")
    return unless word_count > 2000

    raise "Resume is too long (#{word_count} words). Please limit to 2000 words."
  end

  def update_status(message)
    Rails.logger.info("[Pipeline #{@request_id}] #{message}")
    StatusPublisher.publish(@request_id, { status: message })
  end
end
