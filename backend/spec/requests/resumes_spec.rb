require 'rails_helper'

RSpec.describe 'Resumes API', type: :request do
  before do
    # Stub Redis so tests never touch a real server
    allow($redis).to receive(:set)
    allow($redis).to receive(:expire)
    allow($redis).to receive(:get)
    allow($redis).to receive(:del)
    allow($redis).to receive(:publish)
  end

  describe 'POST /api/v1/resumes' do
    context 'with a file upload' do
      it 'returns 202 with a request_id and enqueues the job' do
        file = fixture_file_upload('resume.txt', 'text/plain')

        expect {
          post '/api/v1/resumes', params: { file: file }
        }.to have_enqueued_job(ResumeProcessingJob).with(
          content: an_instance_of(String),
          content_type: 'text/plain',
          original_filename: 'resume.txt',
          request_id: an_instance_of(String),
          template: 'jakes'
        )

        expect(response).to have_http_status(:accepted)
        body = JSON.parse(response.body)
        expect(body['request_id']).to be_present
      end
    end

    context 'with pasted text content' do
      it 'returns 202 and enqueues the job as text/plain' do
        expect {
          post '/api/v1/resumes', params: { content: "John Doe\nEngineer at Google", template: 'modern' }
        }.to have_enqueued_job(ResumeProcessingJob).with(
          content: "John Doe\nEngineer at Google",
          content_type: 'text/plain',
          original_filename: 'pasted-resume.txt',
          request_id: an_instance_of(String),
          template: 'modern'
        )

        expect(response).to have_http_status(:accepted)
      end
    end

    context 'with a valid template' do
      it 'passes the template through to the job' do
        expect {
          post '/api/v1/resumes', params: { content: 'Jane Doe', template: 'minimal' }
        }.to have_enqueued_job(ResumeProcessingJob).with(hash_including(template: 'minimal'))

        expect(response).to have_http_status(:accepted)
      end
    end

    context 'with an invalid template' do
      it 'defaults to jakes' do
        expect {
          post '/api/v1/resumes', params: { content: 'Jane Doe', template: 'hacker-template' }
        }.to have_enqueued_job(ResumeProcessingJob).with(hash_including(template: 'jakes'))

        expect(response).to have_http_status(:accepted)
      end
    end

    context 'without a file or content' do
      it 'returns 400' do
        post '/api/v1/resumes', params: {}

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)['error']).to eq('No file provided')
      end
    end

    context 'with an empty content body' do
      it 'returns 400' do
        post '/api/v1/resumes', params: { content: '' }

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)['error']).to eq('No file provided')
      end
    end

    context 'with an oversized file' do
      it 'returns 413 without enqueuing a job' do
        ClimateControl.modify('MAX_UPLOAD_BYTES' => '10') do
          file = fixture_file_upload('resume.txt', 'text/plain') # fixture is much larger than 10 bytes

          expect {
            post '/api/v1/resumes', params: { file: file }
          }.not_to have_enqueued_job(ResumeProcessingJob)

          expect(response).to have_http_status(:content_too_large)
        end
      end
    end

    context 'with oversized pasted content' do
      it 'returns 413' do
        ClimateControl.modify('MAX_UPLOAD_BYTES' => '10') do
          post '/api/v1/resumes', params: { content: 'This content is definitely longer than ten bytes' }

          expect(response).to have_http_status(:content_too_large)
        end
      end
    end
  end

  describe 'GET /api/v1/resumes/preview' do
    context 'without a request_id' do
      it 'returns 400' do
        get '/api/v1/resumes/preview'

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)['error']).to eq('No request ID provided')
      end
    end

    context 'with an unknown request_id' do
      it 'returns 404' do
        get '/api/v1/resumes/preview', params: { request_id: 'does-not-exist' }

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
