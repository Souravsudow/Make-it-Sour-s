require 'timeout'

module Api
  module V1
    class ResumesController < ApplicationController
      skip_before_action :verify_authenticity_token

      ALLOWED_TEMPLATES = %w[jakes minimal modern].freeze
      STATUS_TTL = 3600

      def create
        template = normalize_template(params[:template])

        if params[:file].present?
          file = params[:file]
          unless file.respond_to?(:content_type) && file.respond_to?(:size)
            render json: { error: 'No file provided' }, status: :bad_request
            return
          end
          if file.size > max_upload_size
            render json: { error: "File too large. Maximum size is #{max_upload_size / 1.megabyte}MB." }, status: :content_too_large
            return
          end

          begin
            file_content = file.read
            content_type = file.content_type
            original_filename = file.original_filename
          rescue => e
            render json: { error: "Failed to read file: #{e.message}" }, status: :bad_request
            return
          end
        elsif (content = params[:content].presence)
          if content.bytesize > max_upload_size
            render json: { error: 'Content too large. Maximum size is 10MB.' }, status: :content_too_large
            return
          end

          file_content = content
          content_type = 'text/plain'
          original_filename = 'pasted-resume.txt'
        else
          render json: { error: 'No file provided' }, status: :bad_request
          return
        end

        request_id = SecureRandom.uuid
        $redis.set("resume_status:#{request_id}", "Starting resume formatting process...")
        $redis.expire("resume_status:#{request_id}", STATUS_TTL)

        ResumeProcessingJob.perform_later(
          content: file_content,
          content_type: content_type,
          original_filename: original_filename,
          request_id: request_id,
          template: template
        )

        render json: { request_id: request_id }, status: :accepted
      rescue StandardError => e
        render json: { error: e.message }, status: :internal_server_error
      end

      def preview
        request_id = params[:request_id]
        if request_id.nil?
          render json: { error: 'No request ID provided' }, status: :bad_request
          return
        end

        result_key = "resume_result:#{request_id}"
        pdf_key = "resume_pdf:#{request_id}"

        if cached_pdf = $redis.get(pdf_key)
          render json: {
            pdf: Base64.strict_encode64(cached_pdf),
            contentType: 'application/pdf'
          }
          return
        end

        result = $redis.get(result_key)
        if result.nil?
          render json: { error: 'No resume found for this ID' }, status: :not_found
          return
        end

        begin
          parsed_result = JSON.parse(result)
          latex = parsed_result['latex']

          dir = Dir.mktmpdir("resume_#{request_id}")
          tex_file = File.join(dir, 'resume.tex')
          File.write(tex_file, latex)

          output = nil
          begin
            Timeout.timeout(ENV.fetch('PDF_COMPILE_TIMEOUT', 60).to_i) do
              output = Dir.chdir(dir) { `pdflatex -interaction=nonstopmode -halt-on-error -no-shell-escape resume.tex 2>&1` }
            end
          rescue Timeout::Error
            Rails.logger.error("PDF compilation timed out for request #{request_id}")
            render json: { error: 'PDF compilation timed out' }, status: :internal_server_error
            return
          end

          unless $?.success?
            Rails.logger.error("PDF compilation failed: #{output}")
            render json: { error: 'Failed to compile PDF' }, status: :internal_server_error
            return
          end

          pdf_file = File.join(dir, 'resume.pdf')
          if File.exist?(pdf_file)
            pdf_content = File.binread(pdf_file)
            $redis.set(pdf_key, pdf_content)
            $redis.expire(pdf_key, 3600)

            name = $redis.get("resume_name:#{request_id}") || { first: "Unknown", last: "User" }.to_json
            render json: {
              pdf: Base64.strict_encode64(pdf_content),
              contentType: 'application/pdf',
              name: name
            }
          else
            render json: { error: 'Failed to generate PDF' }, status: :internal_server_error
          end
        rescue StandardError => e
          render json: { error: "Failed to generate PDF: #{e.message}" }, status: :internal_server_error
        ensure
          FileUtils.remove_entry dir if dir
        end
      end

      private

      def normalize_template(value)
        ALLOWED_TEMPLATES.include?(value.to_s) ? value.to_s : 'jakes'
      end

      def max_upload_size
        ENV.fetch('MAX_UPLOAD_BYTES', (10.megabytes).to_s).to_i
      end
    end
  end
end