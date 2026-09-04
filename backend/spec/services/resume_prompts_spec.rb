require 'rails_helper'

RSpec.describe ResumePrompts do
  let(:sample_data) do
    {
      'name' => { 'first_name' => 'John', 'last_name' => 'Doe' },
      'contact_info' => { 'email' => 'john@example.com' },
      'education' => [],
      'experience' => [],
      'projects' => [],
      'technical_skills' => {},
      'honors' => []
    }.to_json
  end

  describe 'templates' do
    {
      'jakes' => ResumePrompts::JAKES_TEMPLATE,
      'minimal' => ResumePrompts::MINIMAL_TEMPLATE,
      'modern' => ResumePrompts::MODERN_TEMPLATE
    }.each do |name, template|
      it "#{name} template is a complete LaTeX document" do
        expect(template).to include('\\documentclass')
        expect(template).to include('\\begin{document}')
        expect(template).to include('\\end{document}')
      end

      it "#{name} template defines the custom resume commands" do
        expect(template).to include('\\resumeSubheading')
        expect(template).to include('\\resumeItem')
      end
    end

    it 'jakes template uses serif small caps section headings' do
      expect(ResumePrompts::JAKES_TEMPLATE).to include('\\scshape')
    end

    it 'modern template uses sans-serif and an accent color' do
      expect(ResumePrompts::MODERN_TEMPLATE).to include('\\sfdefault')
      expect(ResumePrompts::MODERN_TEMPLATE).to include('\\definecolor{accent}')
    end

    it 'minimal template is black and white (no xcolor)' do
      expect(ResumePrompts::MINIMAL_TEMPLATE).not_to include('\\usepackage{xcolor}')
    end
  end

  describe '.latex_prompt' do
    it 'defaults to the jakes template' do
      prompt = described_class.latex_prompt(sample_data)
      expect(prompt).to include(ResumePrompts::JAKES_TEMPLATE.lines.first.strip)
      expect(prompt).to include('"jakes" template')
    end

    it 'selects the minimal template when requested' do
      prompt = described_class.latex_prompt(sample_data, template: 'minimal')
      expect(prompt).to include('"minimal" template')
      expect(prompt).to include(ResumePrompts::MINIMAL_TEMPLATE.lines.first.strip)
    end

    it 'selects the modern template when requested' do
      prompt = described_class.latex_prompt(sample_data, template: 'modern')
      expect(prompt).to include('"modern" template')
      expect(prompt).to include(ResumePrompts::MODERN_TEMPLATE.lines.first.strip)
    end

    it 'falls back to jakes for an unknown template' do
      prompt = described_class.latex_prompt(sample_data, template: 'weird')
      expect(prompt).to include('"jakes" template')
    end

    it 'includes the resume data to format' do
      prompt = described_class.latex_prompt(sample_data)
      expect(prompt).to include(sample_data)
    end
  end
end
