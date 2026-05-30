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

        mutex = Mutex.new
        condition = ConditionVariable.new

        Thread.new do
          begin
            latex_content = ResumeFormatterService.new(file, request_id).format(mutex, condition)
            $redis.set("resume_status:#{request_id}", "Resume formatting completed successfully!")
            $redis.set("resume_result:#{request_id}", { latex: latex_content }.to_json)
          rescue StandardError => e
            error_message = e.message
            mutex.synchronize { condition.signal }
            $redis.set("resume_status:#{request_id}", "Error: #{error_message}")
          end
        end

        mutex.synchronize do
          condition.wait(mutex)
        end

        render json: { request_id: request_id }, status: :accepted

      rescue StandardError => e
        error_message = e.message
        status = case error_message
        when 'No file provided', 'Invalid file type', 'File too large', 'Unsupported file type',
             'Unable to read DOC file', 'Unable to read DOCX file', 'Not a resume'
          :bad_request
        when 'Invalid API key'
          :unauthorized
        when 'Rate limit exceeded for Fireworks Llama API', 'Rate limit exceeded for Anthropic API',
             'Rate limit exceeded for Gemini API'
          :too_many_requests
        else
          :internal_server_error
        end
        render json: { error: error_message }, status: status
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
          Rails.logger.info("Serving cached PDF for request #{request_id}")
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
          latex = prepare_latex_for_pdf(parsed_result['latex'])

          dir = Dir.mktmpdir("resume_#{request_id}")
          tex_file = File.join(dir, 'resume.tex')
          File.write(tex_file, latex)

          output = Dir.chdir(dir) { `pdflatex -interaction=nonstopmode -halt-on-error resume.tex 2>&1` }
          Rails.logger.info("pdflatex output: #{output}")

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
            Rails.logger.error("PDF file not found after compilation")
            render json: { error: 'Failed to generate PDF' }, status: :internal_server_error
          end

        rescue StandardError => e
          render json: { error: "Failed to generate PDF: #{e.message}" }, status: :internal_server_error
        ensure
          FileUtils.remove_entry dir if dir
        end
      end

      private

      def prepare_latex_for_pdf(latex)
        text = latex.to_s
        text = remove_missing_basictex_packages(text)
        text = replace_titlesec_formatting(text)
        text = remove_enumitem_options(text)
        text = compact_resume_layout(text)
        text
      end

      def remove_missing_basictex_packages(latex)
        latex
          .gsub(/\\usepackage(?:\[[^\]]*\])?\{fullpage\}\s*\n?/, '')
          .gsub(/\\usepackage(?:\[[^\]]*\])?\{titlesec\}\s*\n?/, '')
          .gsub(/\\usepackage(?:\[[^\]]*\])?\{marvosym\}\s*\n?/, '')
          .gsub(/\\usepackage(?:\[[^\]]*\])?\{enumitem\}\s*\n?/, '')
          .gsub(/\\usepackage\[[^\]]*dvipsnames[^\]]*\]\{color\}/i, '\\usepackage{color}')
          .gsub(/\\usepackage\[[^\]]*dvipsnames[^\]]*\]\{xcolor\}/i, '\\usepackage{xcolor}')
      end

      def replace_titlesec_formatting(latex)
        replacement = <<~'LATEX'
          \makeatletter
          \renewcommand{\section}[1]{\vspace{-4pt}\par\noindent{\large\scshape #1}\par\vspace{2pt}\hrule\vspace{5pt}}
          \makeatother
        LATEX
        latex.gsub(
          /\\titleformat\{\\section\}\{\s*\\vspace\{-4pt\}\\scshape\\raggedright\\large\s*\}\{\}\{0em\}\{\}\[\\color\{black\}\\titlerule \\vspace\{-5pt\}\]\s*/m,
          replacement
        )
      end

      def remove_enumitem_options(latex)
        latex
          .gsub(/\\newcommand\{\\resumeSubHeadingListStart\}\{\\begin\{itemize\}\[[^\]]*label=\{\}[^\]]*\]\}/,
                '\\newcommand{\\resumeSubHeadingListStart}{\\begin{itemize}\\renewcommand{\\labelitemi}{}}')
          .gsub(/\\begin\{itemize\}\[[^\]]*label=\{\}[^\]]*\]/,
                '\\begin{itemize}\\renewcommand{\\labelitemi}{}')
          .gsub(/\\begin\{itemize\}\[[^\]]*\]/, '\\begin{itemize}')
      end

      def compact_resume_layout(latex)
        text = latex.dup

        # Font size 11pt set karo
        text.sub!(/\\documentclass\[([^\]]*)\]\{article\}/) do
          options = $1.split(',').map(&:strip)
          options = options.reject { |option| option.match?(/\A\d+pt\z/) }
          "\\documentclass[#{(['letterpaper', '11pt'] + options).uniq.join(',')}]{article}"
        end

        # Geometry package add karo agar nahi hai
        unless text.match?(/\\usepackage(?:\[[^\]]*\])?\{geometry\}/)
          text.sub!(/\\documentclass\[[^\]]*\]\{article\}\n/) do |match|
            "#{match}\\usepackage[top=0.4in, bottom=0.4in, left=0.5in, right=0.5in]{geometry}\n"
          end
        end

        # Paragraph spacing
        text.sub!(/\\begin\{document\}/, 
          "\\setlength{\\parskip}{0pt}\n\\setlength{\\itemsep}{0pt}\n\\setlength{\\parsep}{0pt}\n\\setlength{\\parindent}{0pt}\n\\begin{document}")

        # Purane manual margin commands remove karo — geometry handle karega
        text.gsub!(/\\addtolength\{\\topmargin\}\{[^}]*\}\n?/, '')
        text.gsub!(/\\addtolength\{\\oddsidemargin\}\{[^}]*\}\n?/, '')
        text.gsub!(/\\addtolength\{\\evensidemargin\}\{[^}]*\}\n?/, '')
        text.gsub!(/\\addtolength\{\\textwidth\}\{[^}]*\}\n?/, '')
        text.gsub!(/\\addtolength\{\\textheight\}\{[^}]*\}\n?/, '')
        text.gsub!(/\\setlength\{\\topmargin\}\{[^}]*\}\n?/, '')
        text.gsub!(/\\setlength\{\\oddsidemargin\}\{[^}]*\}\n?/, '')
        text.gsub!(/\\setlength\{\\evensidemargin\}\{[^}]*\}\n?/, '')
        text.gsub!(/\\setlength\{\\textwidth\}\{[^}]*\}\n?/, '')
        text.gsub!(/\\setlength\{\\textheight\}\{[^}]*\}\n?/, '')

        # Vspace tighten karo
        text.gsub!(/\\vspace\{-7pt\}/, '\\vspace{-8pt}')
        text.gsub!(/\\vspace\{-5pt\}/, '\\vspace{-6pt}')
        text.gsub!(/\\vspace\{-4pt\}/, '\\vspace{-6pt}')
        text.gsub!(/\\vspace\{-3pt\}/, '\\vspace{-5pt}')
        text.gsub!(/\\vspace\{-2pt\}/, '\\vspace{-3pt}')

        text.gsub!(/\\item\small\{\s*\{#1 \\vspace\{-3pt\}\}\s*\}/m, '\\item\\small{{#1 \\vspace{-3pt}}}')
        text.gsub!(/\\small#1 & #2/, '\\small#1 & #2')

        text
      end
    end
  end
end
