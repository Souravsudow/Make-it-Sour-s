module Api
  module V1
    class ResumesController < ApplicationController
      skip_before_action :verify_authenticity_token

      def create
        file = params[:file]
        if file.nil?
          render json: { error: 'No file provided' }, status: :bad_request
          return
        end
        unless file.respond_to?(:content_type) && file.respond_to?(:size)
          render json: { error: 'No file provided' }, status: :bad_request
          return
        end

        request_id = SecureRandom.uuid
        $redis.set("resume_status:#{request_id}", "Starting resume formatting process...")

        begin
          file_content = file.read
          content_type = file.content_type
          original_filename = file.original_filename
        rescue => e
          render json: { error: "Failed to read file: #{e.message}" }, status: :bad_request
          return
        end

        Thread.new do
          begin
            latex_content = ResumeFormatterService.new(
              content: file_content,
              content_type: content_type,
              original_filename: original_filename,
              request_id: request_id
            ).format
            $redis.set("resume_status:#{request_id}", "Resume formatting completed successfully!")
            $redis.set("resume_result:#{request_id}", { latex: latex_content }.to_json)
          rescue StandardError => e
            $redis.set("resume_status:#{request_id}", "Error: #{e.message}")
          end
        end

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

          output = Dir.chdir(dir) { `pdflatex -interaction=nonstopmode -halt-on-error resume.tex 2>&1` }
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
    end
  end
end