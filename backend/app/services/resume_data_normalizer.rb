require "json-schema"

class ResumeDataNormalizer
  class ValidationError < StandardError; end

  ARRAY_FIELDS = %w[education experience projects honors].freeze

  SCHEMA = {
    "type" => "object",
    "required" => %w[name contact_info education experience projects technical_skills honors],
    "properties" => {
      "name" => {
        "type" => "object",
        "properties" => {
          "first_name" => { "type" => "string" },
          "last_name" => { "type" => "string" }
        },
        "additionalProperties" => { "type" => "string" }
      },
      "contact_info" => {
        "type" => "object",
        "additionalProperties" => { "type" => "string" }
      },
      "education" => { "type" => "array", "items" => { "type" => "object" } },
      "experience" => { "type" => "array", "items" => { "type" => "object" } },
      "projects" => { "type" => "array", "items" => { "type" => "object" } },
      "technical_skills" => {
        "type" => "object",
        "additionalProperties" => {
          "type" => "array",
          "items" => { "type" => "string" }
        }
      },
      "honors" => { "type" => "array", "items" => { "type" => "object" } }
    },
    "additionalProperties" => true
  }.freeze

  class << self
    def normalize(raw)
      raw = hash_value(raw)
      {
        "name" => normalize_name(raw["name"] || raw),
        "contact_info" => normalize_contact(raw),
        "education" => normalize_collection(raw["education"]).filter_map { |entry| normalize_education(entry) },
        "experience" => normalize_collection(raw["experience"]).filter_map { |entry| normalize_experience(entry) },
        "projects" => normalize_collection(raw["projects"]).filter_map { |entry| normalize_project(entry) },
        "technical_skills" => normalize_skills(raw["technical_skills"] || raw["skills"]),
        "honors" => normalize_collection(raw["honors"] || raw["leadership"] || raw["awards"]).filter_map { |entry| normalize_honor(entry) }
      }
    end

    def validate!(data)
      errors = JSON::Validator.fully_validate(SCHEMA, data)
      return data if errors.empty?

      raise ValidationError, "Extracted resume data is invalid: #{errors.join('; ')}"
    end

    private

    def normalize_name(value)
      if value.is_a?(String)
        parts = value.strip.split(/\s+/, 2)
        return { "first_name" => clean_string(parts[0]), "last_name" => clean_string(parts[1]) }
      end

      value = hash_value(value)
      first = first_string(value, "first_name", "first", "given_name")
      last = first_string(value, "last_name", "last", "family_name")
      full_name = first_string(value, "full_name", "name")

      if first.empty? && last.empty? && !full_name.empty?
        parts = full_name.split(/\s+/, 2)
        first = clean_string(parts[0])
        last = clean_string(parts[1])
      end

      { "first_name" => first, "last_name" => last }
    end

    def normalize_contact(raw)
      contact = hash_value(raw["contact_info"])
      contact = contact.merge(hash_value(raw["contact"]))
      contact = contact.merge(hash_value(raw["social_media"]))

      {
        "email" => first_string(contact, "email", "mail"),
        "phone" => first_string(contact, "phone", "phone_number", "mobile"),
        "location" => first_string(contact, "location", "address"),
        "linkedin" => first_string(contact, "linkedin", "linkedin_url"),
        "github" => first_string(contact, "github", "github_url"),
        "portfolio" => first_string(contact, "portfolio", "website", "personal_website")
      }
    end

    def normalize_education(entry)
      entry = hash_value(entry)
      data = {
        "school" => first_string(entry, "school", "institution", "university", "college"),
        "degree" => first_string(entry, "degree", "program"),
        "location" => first_string(entry, "location"),
        "graduation_date" => first_string(entry, "graduation_date", "date", "dates", "year"),
        "gpa" => first_string(entry, "gpa", "GPA"),
        "coursework" => string_list(entry["coursework"] || entry["relevant_coursework"])
      }
      empty_entry?(data) ? nil : data
    end

    def normalize_experience(entry)
      entry = hash_value(entry)
      data = {
        "title" => first_string(entry, "title", "role", "position"),
        "company" => first_string(entry, "company", "organization", "employer"),
        "location" => first_string(entry, "location"),
        "dates" => first_string(entry, "dates", "date", "duration", "period"),
        "bullets" => string_list(entry["bullets"] || entry["bullet_points"] || entry["achievements"] || entry["responsibilities"] || entry["description"])
      }
      empty_entry?(data) ? nil : data
    end

    def normalize_project(entry)
      entry = { "name" => entry } if entry.is_a?(String)
      entry = hash_value(entry)
      data = {
        "name" => first_string(entry, "name", "title", "project_name"),
        "technologies" => string_list(entry["technologies"] || entry["technologies_used"] || entry["tech_stack"] || entry["skills"]),
        "date" => first_string(entry, "date", "dates", "duration", "period"),
        "bullets" => string_list(entry["bullets"] || entry["bullet_points"] || entry["details"] || entry["description"])
      }
      empty_entry?(data) ? nil : data
    end

    def normalize_honor(entry)
      entry = { "name" => entry } if entry.is_a?(String)
      entry = hash_value(entry)
      data = {
        "name" => first_string(entry, "name", "title", "award", "role"),
        "organization" => first_string(entry, "organization", "issuer", "company"),
        "date" => first_string(entry, "date", "dates", "year"),
        "location" => first_string(entry, "location"),
        "bullets" => string_list(entry["bullets"] || entry["bullet_points"] || entry["description"])
      }
      empty_entry?(data) ? nil : data
    end

    def normalize_skills(value)
      return {} if value.nil?
      return { "skills" => string_list(value) } unless value.is_a?(Hash)

      value.each_with_object({}) do |(key, raw_list), result|
        list = string_list(raw_list)
        result[clean_string(key)] = list unless list.empty?
      end
    end

    def normalize_collection(value)
      case value
      when nil
        []
      when Array
        value.compact
      when Hash
        value.keys.all? { |key| key.to_s.match?(/\A\d+\z/) } ? value.values.compact : [value]
      when String
        value.strip.empty? ? [] : [value]
      else
        []
      end
    end

    def string_list(value)
      case value
      when nil
        []
      when Array
        value.flat_map { |item| string_list(item) }.map(&:strip).reject(&:empty?)
      when Hash
        value.values.flat_map { |item| string_list(item) }.map(&:strip).reject(&:empty?)
      when String
        value.split(/[\n;,]+/).map(&:strip).reject(&:empty?)
      else
        [clean_string(value)].reject(&:empty?)
      end
    end

    def first_string(hash, *keys)
      keys.each do |key|
        value = hash[key] || hash[key.to_sym]
        text = clean_string(value)
        return text unless text.empty?
      end
      ""
    end

    def hash_value(value)
      value.is_a?(Hash) ? value : {}
    end

    def clean_string(value)
      case value
      when nil
        ""
      when Array
        value.map { |item| clean_string(item) }.reject(&:empty?).join(", ")
      when Hash
        value.values.map { |item| clean_string(item) }.reject(&:empty?).join(", ")
      else
        value.to_s.strip
      end
    end

    def empty_entry?(hash)
      hash.values.all? { |value| value.respond_to?(:empty?) ? value.empty? : value.nil? }
    end
  end
end
