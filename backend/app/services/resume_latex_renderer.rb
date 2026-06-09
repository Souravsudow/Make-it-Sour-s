class ResumeLatexRenderer
  LATEX_ESCAPE = {
    "\\" => "\\textbackslash{}",
    "&" => "\\&",
    "%" => "\\%",
    "$" => "\\$",
    "#" => "\\#",
    "_" => "\\_",
    "{" => "\\{",
    "}" => "\\}",
    "~" => "\\textasciitilde{}",
    "^" => "\\textasciicircum{}",
    "|" => "\\textbar{}",
    "<" => "\\textless{}",
    ">" => "\\textgreater{}"
  }.freeze

  CONTACT_SEPARATOR = " \\textbullet{} "

  def initialize(data)
    @data = data || {}
  end

  def render
    [
      preamble,
      "\\begin{document}",
      header,
      education_section,
      experience_section,
      projects_section,
      honors_section,
      skills_section,
      "\\end{document}"
    ].compact.join("\n")
  end

  private

  def preamble
    <<~LATEX
      \\documentclass[letterpaper,10pt]{article}
      \\usepackage[utf8]{inputenc}
      \\usepackage[T1]{fontenc}
      \\usepackage{textcomp}
      \\usepackage[top=0.4in, bottom=0.4in, left=0.5in, right=0.5in]{geometry}
      \\usepackage[hidelinks]{hyperref}
      \\usepackage[english]{babel}
      \\usepackage{tabularx}
      \\input{glyphtounicode}

      \\pagestyle{empty}
      \\setlength{\\tabcolsep}{0in}
      \\raggedbottom
      \\raggedright
      \\setlength{\\parindent}{0pt}
      \\setlength{\\parskip}{0pt}
      \\urlstyle{same}
      \\pdfgentounicode=1

      \\newcommand{\\resumeItem}[1]{\\item\\small{#1}}
      \\newcommand{\\resumeSubheading}[4]{
        \\vspace{1pt}\\item
          \\begin{tabular*}{0.97\\textwidth}[t]{l@{\\extracolsep{\\fill}}r}
            \\textbf{#1} & #2 \\\\
            \\textit{\\small#3} & \\textit{\\small #4} \\\\
          \\end{tabular*}\\vspace{-4pt}
      }
      \\newcommand{\\resumeProjectHeading}[2]{
          \\vspace{1pt}\\item
          \\begin{tabular*}{0.97\\textwidth}{l@{\\extracolsep{\\fill}}r}
            \\small\\textbf{#1} & \\small#2 \\\\
          \\end{tabular*}\\vspace{-4pt}
      }
      \\newcommand{\\resumeSection}[1]{\\vspace{5pt}\\noindent{\\textbf{\\large #1}}\\par\\vspace{3pt}}
      \\newcommand{\\resumeSubHeadingListStart}{\\begin{list}{}{\\setlength{\\leftmargin}{0in}\\setlength{\\itemsep}{0pt}\\setlength{\\parsep}{0pt}\\setlength{\\topsep}{0pt}}}
      \\newcommand{\\resumeSubHeadingListEnd}{\\end{list}\\vspace{2pt}}
      \\newcommand{\\resumeItemListStart}{\\begin{itemize}\\setlength{\\itemsep}{0pt}\\setlength{\\parsep}{0pt}\\setlength{\\topsep}{0pt}\\setlength{\\leftmargin}{0.2in}}
      \\newcommand{\\resumeItemListEnd}{\\end{itemize}}
    LATEX
  end

  def header
    name = [dig("name", "first_name"), dig("name", "last_name")].reject(&:empty?).join(" ")
    name = "Resume User" if name.empty?
    contacts = %w[email phone location linkedin github portfolio].map { |key| dig("contact_info", key) }.reject(&:empty?)

    header_tex = "{\\LARGE\\textbf{#{escape(name)}}}"
    header_tex += "\\\\[3pt]" if contacts.any?
    header_tex += "\\small #{contacts.map { |item| escape(item) }.join(CONTACT_SEPARATOR)}" if contacts.any?

    <<~LATEX
      \\begin{center}
          #{header_tex}
      \\end{center}
    LATEX
  end

  def education_section
    entries = array("education")
    return nil if entries.empty?

    body = entries.map do |entry|
      degree_line = [sanitize_text(entry["degree"]), entry["gpa"].to_s.empty? ? nil : "GPA: #{sanitize_text(entry["gpa"])}", list_text(entry["coursework"])].compact.reject(&:empty?).join(", ")
      "\\resumeSubheading{#{escape(entry["school"])}}{#{escape(entry["location"])}}{#{escape(degree_line)}}{#{escape(entry["graduation_date"])}}"
    end.join("\n")

    section("Education", "\\resumeSubHeadingListStart\n#{body}\n\\resumeSubHeadingListEnd")
  end

  def experience_section
    entries = array("experience")
    return nil if entries.empty?

    body = entries.map do |entry|
      title = entry["title"].to_s.empty? ? entry["company"] : entry["title"]
      company = entry["company"].to_s == title ? "" : entry["company"].to_s
      [
        "\\resumeSubheading{#{escape(title)}}{#{escape(entry["dates"])}}{#{escape(company)}}{#{escape(entry["location"])}}",
        item_list(entry["bullets"])
      ].compact.join("\n")
    end.join("\n")

    section("Experience", "\\resumeSubHeadingListStart\n#{body}\n\\resumeSubHeadingListEnd")
  end

  def projects_section
    entries = array("projects")
    return nil if entries.empty?

    body = entries.map do |entry|
      title = "\\textbf{#{escape(entry["name"])}}"
      technologies = list_text(entry["technologies"])
      title = "#{title} #{CONTACT_SEPARATOR} \\emph{#{escape(technologies)}}" unless technologies.empty?
      [
        "\\resumeProjectHeading{#{title}}{#{escape(entry["date"])}}",
        item_list(entry["bullets"])
      ].compact.join("\n")
    end.join("\n")

    section("Projects", "\\resumeSubHeadingListStart\n#{body}\n\\resumeSubHeadingListEnd")
  end

  def honors_section
    entries = array("honors")
    return nil if entries.empty?

    body = entries.map do |entry|
      title_parts = ["\\textbf{#{escape(entry["name"])}}", escape(entry["organization"])].reject(&:empty?)
      title = title_parts.join(" #{CONTACT_SEPARATOR} ")
      [
        "\\resumeProjectHeading{#{title}}{#{escape(entry["date"])}}",
        item_list(entry["bullets"])
      ].compact.join("\n")
    end.join("\n")

    section("Honors & Awards", "\\resumeSubHeadingListStart\n#{body}\n\\resumeSubHeadingListEnd")
  end

  def skills_section
    skills = hash("technical_skills").reject { |_, value| Array(value).empty? }
    return nil if skills.empty?

    lines = skills.map do |category, values|
      "\\textbf{#{escape(titleize(category))}}: #{escape(list_text(values))}"
    end

    section(
      "Technical Skills",
      "\\resumeSubHeadingListStart\n\\item\\small{\n#{lines.join(" \\\\\n")}\n}\n\\resumeSubHeadingListEnd"
    )
  end

  def item_list(items)
    items = Array(items).map(&:to_s).map(&:strip).reject(&:empty?)
    return nil if items.empty?

    "\\resumeItemListStart\n#{items.map { |item| "\\resumeItem{#{escape(item)}}" }.join("\n")}\n\\resumeItemListEnd"
  end

  def section(title, body)
    return nil if body.to_s.strip.empty?

    "\\resumeSection{#{escape(title)}}\n#{body}"
  end

  def escape(value)
    value.to_s.gsub(/[\\&%$#_{}~^|<>]/) { |char| LATEX_ESCAPE[char] || char }
  end

  def sanitize_text(value)
    value.to_s.strip
  end

  def list_text(value)
    Array(value).map { |item| sanitize_text(item) }.reject(&:empty?).join(", ")
  end

  def titleize(value)
    value.to_s.tr("_", " ").split.map(&:capitalize).join(" ")
  end

  def dig(*keys)
    value = @data.dig(*keys)
    value.to_s.strip
  end

  def array(key)
    Array(@data[key])
  end

  def hash(key)
    @data[key].is_a?(Hash) ? @data[key] : {}
  end
end
