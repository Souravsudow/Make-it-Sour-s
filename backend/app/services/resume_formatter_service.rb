class ResumeFormatterService
  ALLOWED_CONTENT_TYPES = [
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'text/plain'
  ].freeze

  # Initialize with content string instead of file object
  def initialize(content:, content_type:, original_filename:, request_id: nil)
    @content = content
    @content_type = content_type
    @original_filename = original_filename
    @request_id = request_id
    validate_content!
  end

  def format
    text = extract_text_from_content
    gemini_service = GeminiApiService.new(@request_id)
    gemini_service.format_resume(text)
  rescue StandardError => e
    handle_error(e)
  end

  private

  def validate_content!
    raise 'No file provided' if @content.nil? || @content.empty?
    raise 'Invalid file type' unless ALLOWED_CONTENT_TYPES.include?(@content_type)
    raise 'File too large' if @content.bytesize > 10.megabytes
  end

  def extract_text_from_content
    case @content_type
    when 'text/plain'
      @content
    when 'application/pdf'
      extract_text_from_pdf
    when 'application/msword'
      extract_text_from_doc
    when 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      extract_text_from_docx
    else
      raise 'Unsupported file type'
    end
  end

  def extract_text_from_pdf
    begin
      # Write content to a temporary file
      tempfile = Tempfile.new(['resume', '.pdf'])
      tempfile.binmode
      tempfile.write(@content)
      tempfile.rewind

      reader = PDF::Reader.new(tempfile.path)
      text = ""
      reader.pages.each_with_index do |page, index|
        begin
          page_text = page.text.to_s
          text << page_text
          text << "\n" unless page_text.end_with?("\n")
        rescue StandardError => e
          Rails.logger.error("Error reading page #{index + 1}: #{e.message}")
        end
      end
      text = clean_text(text)
      raise 'No text content found in PDF' if text.strip.empty?
      text
    rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError => e
      Rails.logger.error("PDF parsing error: #{e.message}")
      raise 'Unable to read PDF file: The file appears to be corrupted or in an unsupported format'
    rescue StandardError => e
      Rails.logger.error("Error extracting text from PDF file: #{e.message}")
      raise 'Unable to read PDF file'
    ensure
      tempfile.close! if tempfile
    end
  end

  def extract_text_from_doc
    tempfile = Tempfile.new(['resume', '.doc'])
    tempfile.binmode
    tempfile.write(@content)
    tempfile.rewind

    begin
      extractor = MSWordDoc::Extractor.load(tempfile.path)
      text = extractor.whole_contents
      clean_text(text)
    rescue StandardError => e
      Rails.logger.error("Error extracting text from DOC file: #{e.message}")
      raise 'Unable to read DOC file'
    ensure
      tempfile.close!
    end
  end

  def extract_text_from_docx
    tempfile = Tempfile.new(['resume', '.docx'])
    tempfile.binmode
    tempfile.write(@content)
    tempfile.rewind

    begin
      doc = Docx::Document.open(tempfile.path)
      text = doc.paragraphs.map(&:text).join("\n")
      clean_text(text)
    rescue StandardError => e
      Rails.logger.error("Error extracting text from DOCX file: #{e.message}")
      raise 'Unable to read DOCX file'
    ensure
      tempfile.close!
    end
  end

  def clean_text(text)
    text.gsub(/[^\S\n]+/, ' ')  # Replace multiple spaces with single space
        .gsub(/\n{3,}/, "\n\n")  # Replace multiple newlines with double newline
        .strip
  end

  def handle_error(error)
    case error.message
    when 'No file provided', 'Invalid file type', 'File too large', 'Unsupported file type',
         'Unable to read DOC file', 'Unable to read DOCX file', 'Unable to read PDF file'
      raise error
    else
      raise error
    end
  end
end