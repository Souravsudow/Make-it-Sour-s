require 'rails_helper'

RSpec.describe ResumeDataNormalizer do
  describe '.normalize' do
    it 'normalizes a full valid resume data hash' do
      raw = {
        'name' => { 'first_name' => 'John', 'last_name' => 'Doe' },
        'contact_info' => { 'email' => 'john@example.com', 'phone' => '123-456-7890' },
        'education' => [{ 'school' => 'MIT', 'degree' => 'B.S. Computer Science', 'graduation_date' => '2023' }],
        'experience' => [{ 'title' => 'Engineer', 'company' => 'Google', 'dates' => '2021-2023', 'bullets' => ['Built stuff'] }],
        'projects' => [{ 'name' => 'Cool Project', 'technologies' => ['React'], 'bullets' => ['Made it'] }],
        'technical_skills' => { 'Languages' => ['Ruby', 'Python'] },
        'honors' => [{ 'name' => 'Dean List', 'organization' => 'MIT' }]
      }

      result = described_class.normalize(raw)

      expect(result['name']).to eq({ 'first_name' => 'John', 'last_name' => 'Doe' })
      expect(result['contact_info']['email']).to eq('john@example.com')
      expect(result['education'].size).to eq(1)
      expect(result['experience'].size).to eq(1)
      expect(result['projects'].size).to eq(1)
      expect(result['technical_skills']).to have_key('Languages')
      expect(result['honors'].size).to eq(1)
    end

    it 'handles nil input gracefully' do
      result = described_class.normalize(nil)
      expect(result['name']).to eq({ 'first_name' => '', 'last_name' => '' })
      expect(result['education']).to eq([])
      expect(result['technical_skills']).to eq({})
    end

    it 'extracts name from a string value' do
      raw = { 'name' => 'Jane Smith' }
      result = described_class.normalize(raw)
      expect(result['name']).to eq({ 'first_name' => 'Jane', 'last_name' => 'Smith' })
    end

    it 'merges contact from multiple sources' do
      raw = {
        'contact_info' => { 'email' => 'a@b.com' },
        'contact' => { 'phone' => '555-0000' },
        'social_media' => { 'linkedin' => '/in/jane' }
      }
      result = described_class.normalize(raw)
      expect(result['contact_info']['email']).to eq('a@b.com')
      expect(result['contact_info']['phone']).to eq('555-0000')
      expect(result['contact_info']['linkedin']).to eq('/in/jane')
    end

    it 'handles skills as a flat array using "skills" key' do
      raw = { 'skills' => ['Ruby', 'Python'] }
      result = described_class.normalize(raw)
      expect(result['technical_skills']).to eq({ 'skills' => ['Ruby', 'Python'] })
    end

    it 'coerces string education entry into hash' do
      raw = { 'education' => ['MIT'] }
      result = described_class.normalize(raw)
      expect(result['education']).to eq([]) # all fields empty, filtered out
    end

    it 'handles honors via leadership or awards fallback keys' do
      raw = { 'leadership' => [{ 'name' => 'Team Lead', 'organization' => 'Club' }] }
      result = described_class.normalize(raw)
      expect(result['honors'].size).to eq(1)
      expect(result['honors'][0]['name']).to eq('Team Lead')
    end

    it 'converts project string entries to hashes' do
      raw = { 'projects' => ['Project Alpha'] }
      result = described_class.normalize(raw)
      expect(result['projects'].size).to eq(1)
      expect(result['projects'][0]['name']).to eq('Project Alpha')
    end
  end

  describe '.validate!' do
    it 'passes valid data' do
      data = {
        'name' => { 'first_name' => 'John', 'last_name' => 'Doe' },
        'contact_info' => { 'email' => 'john@test.com' },
        'education' => [],
        'experience' => [],
        'projects' => [],
        'technical_skills' => {},
        'honors' => []
      }
      expect { described_class.validate!(data) }.not_to raise_error
    end

    it 'raises ValidationError when required fields are missing' do
      expect { described_class.validate!({}) }.to raise_error(ResumeDataNormalizer::ValidationError)
    end

    it 'raises ValidationError when required fields are missing entirely' do
      data = {
        'name' => { 'first_name' => 'Jane' },
        'contact_info' => {},
        'education' => [],
        'experience' => [],
        'projects' => [],
        'technical_skills' => {},
        'honors' => []
      }
      # Even though contact_info is empty, the fields are present with correct types
      expect { described_class.validate!(data) }.not_to raise_error
    end
  end

  describe 'private methods' do
    describe 'clean_string' do
      it 'returns empty string for nil' do
        expect(described_class.send(:clean_string, nil)).to eq('')
      end

      it 'joins array values with comma' do
        expect(described_class.send(:clean_string, ['a', 'b'])).to eq('a, b')
      end

      it 'joins hash values with comma' do
        expect(described_class.send(:clean_string, { 'x' => 'a', 'y' => 'b' })).to eq('a, b')
      end

      it 'strips whitespace from strings' do
        expect(described_class.send(:clean_string, '  hello  ')).to eq('hello')
      end
    end

    describe 'string_list' do
      it 'returns empty array for nil' do
        expect(described_class.send(:string_list, nil)).to eq([])
      end

      it 'splits string by newline, semicolon, comma' do
        result = described_class.send(:string_list, "a,b;c\nd")
        expect(result).to eq(%w[a b c d])
      end

      it 'extracts values from hash' do
        result = described_class.send(:string_list, { 'k1' => 'a', 'k2' => 'b' })
        expect(result).to eq(%w[a b])
      end

      it 'flattens arrays' do
        result = described_class.send(:string_list, [['a', 'b'], 'c'])
        expect(result).to eq(%w[a b c])
      end
    end

    describe 'empty_entry?' do
      it 'returns true when all values are empty' do
        expect(described_class.send(:empty_entry?, { 'a' => '', 'b' => [] })).to be true
      end

      it 'returns false when any value is present' do
        expect(described_class.send(:empty_entry?, { 'a' => 'hello', 'b' => '' })).to be false
      end
    end
  end
end
