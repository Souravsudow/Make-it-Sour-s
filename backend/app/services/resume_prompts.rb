module ResumePrompts
  # Jake's original LaTeX template code
  JAKES_TEMPLATE = <<~'LATEX'
\documentclass[letterpaper,11pt]{article}

\usepackage{latexsym}
\usepackage[empty]{fullpage}
\usepackage{titlesec}
\usepackage{marvosym}
\usepackage[usenames,dvipsnames]{color}
\usepackage{verbatim}
\usepackage{enumitem}
\usepackage[hidelinks]{hyperref}
\usepackage{fancyhdr}
\usepackage[english]{babel}
\usepackage{tabularx}
\input{glyphtounicode}


%----------FONT OPTIONS----------
% sans-serif
% \usepackage[sfdefault]{FiraSans}
% \usepackage[sfdefault]{roboto}
% \usepackage[sfdefault]{noto-sans}
% \usepackage[default]{sourcesanspro}

% serif
% \usepackage{CormorantGaramond}
% \usepackage{charter}


\pagestyle{fancy}
\fancyhf{} % clear all header and footer fields
\fancyfoot{}
\renewcommand{\headrulewidth}{0pt}
\renewcommand{\footrulewidth}{0pt}

% Adjust margins
\addtolength{\oddsidemargin}{-0.5in}
\addtolength{\evensidemargin}{-0.5in}
\addtolength{\textwidth}{1in}
\addtolength{\topmargin}{-.5in}
\addtolength{\textheight}{1.0in}

\urlstyle{same}

\raggedbottom
\raggedright
\setlength{\tabcolsep}{0in}

% Sections formatting
\titleformat{\section}{
  \vspace{-4pt}\scshape\raggedright\large
}{}{0em}{}[\color{black}\titlerule \vspace{-5pt}]

% Ensure that generate pdf is machine readable/ATS parsable
\pdfgentounicode=1

%-------------------------
% Custom commands
\newcommand{\resumeItem}[1]{
  \item\small{
    {#1 \vspace{-2pt}}
  }
}

\newcommand{\resumeSubheading}[4]{
  \vspace{-2pt}\item
    \begin{tabular*}{0.97\textwidth}[t]{l@{\extracolsep{\fill}}r}
      \textbf{#1} & #2 \\
      \textit{\small#3} & \textit{\small #4} \\
    \end{tabular*}\vspace{-7pt}
}

\newcommand{\resumeSubSubheading}[2]{
    \item
    \begin{tabular*}{0.97\textwidth}{l@{\extracolsep{\fill}}r}
      \textit{\small#1} & \textit{\small #2} \\
    \end{tabular*}\vspace{-7pt}
}

\newcommand{\resumeProjectHeading}[2]{
    \item
    \begin{tabular*}{0.97\textwidth}{l@{\extracolsep{\fill}}r}
      \small#1 & #2 \\
    \end{tabular*}\vspace{-7pt}
}

\newcommand{\resumeSubItem}[1]{\resumeItem{#1}\vspace{-4pt}}

\renewcommand\labelitemii{$\vcenter{\hbox{\tiny$\bullet$}}$}

\newcommand{\resumeSubHeadingListStart}{\begin{list}{}{\setlength{\leftmargin}{0.15in}\setlength{\itemsep}{0pt}\setlength{\parsep}{0pt}\setlength{\topsep}{0pt}}}
\newcommand{\resumeSubHeadingListEnd}{\end{list}}
\newcommand{\resumeItemListStart}{\begin{itemize}}
\newcommand{\resumeItemListEnd}{\end{itemize}\vspace{-5pt}}

%-------------------------------------------
%%%%%%  RESUME STARTS HERE  %%%%%%%%%%%%%%%%%%%%%%%%%%%%


\begin{document}

%----------HEADING----------
\begin{center}
    \textbf{\Huge \scshape Jake Ryan} \\ \vspace{1pt}
    \small 123-456-7890 $|$ \href{mailto:x@x.com}{\underline{jake@su.edu}} $|$
    \href{https://linkedin.com/in/...}{\underline{linkedin.com/in/jake}} $|$
    \href{https://github.com/...}{\underline{github.com/jake}}
\end{center}


%-----------EDUCATION-----------
\section{Education}
  \resumeSubHeadingListStart
    \resumeSubheading
      {Southwestern University}{Georgetown, TX}
      {Bachelor of Arts in Computer Science, Minor in Business}{Aug. 2018 -- May 2021}
    \resumeSubheading
      {Blinn College}{Bryan, TX}
      {Associate's in Liberal Arts}{Aug. 2014 -- May 2018}
  \resumeSubHeadingListEnd


%-----------EXPERIENCE-----------
\section{Experience}
  \resumeSubHeadingListStart

    \resumeSubheading
      {Undergraduate Research Assistant}{June 2020 -- Present}
      {Texas A\&M University}{College Station, TX}
      \resumeItemListStart
        \resumeItem{Developed a REST API using FastAPI and PostgreSQL to store data from learning management systems}
        \resumeItem{Developed a full-stack web application using Flask, React, PostgreSQL and Docker to analyze GitHub data}
        \resumeItem{Explored ways to visualize GitHub collaboration in a classroom setting}
      \resumeItemListEnd

% -----------Multiple Positions Heading-----------
% Example of how to add multiple positions to a job:
%    \resumeSubSubheading
%     {Software Engineer I}{Oct 2014 - Sep 2016}
%     \resumeItemListStart
%        \resumeItem{Apache Beam}
%          {Apache Beam is a unified model for defining both batch and streaming data-parallel processing pipelines}
%     \resumeItemListEnd
%    \resumeSubHeadingListEnd
%-------------------------------------------

    \resumeSubheading
      {Information Technology Support Specialist}{Sep. 2018 -- Present}
      {Southwestern University}{Georgetown, TX}
      \resumeItemListStart
        \resumeItem{Communicate with managers to set up campus computers used on campus}
        \resumeItem{Assess and troubleshoot computer problems brought by students, faculty and staff}
        \resumeItem{Maintain upkeep of computers, classroom equipment, and 200 printers across campus}
    \resumeItemListEnd

    \resumeSubheading
      {Artificial Intelligence Research Assistant}{May 2019 -- July 2019}
      {Southwestern University}{Georgetown, TX}
      \resumeItemListStart
        \resumeItem{Explored methods to generate video game dungeons based off of \emph{The Legend of Zelda}}
        \resumeItem{Developed a game in Java to test the generated dungeons}
        \resumeItem{Contributed 50K+ lines of code to an established codebase via Git}
        \resumeItem{Conducted  a human subject study to determine which video game dungeon generation technique is enjoyable}
        \resumeItem{Wrote an 8-page paper and gave multiple presentations on-campus}
        \resumeItem{Presented virtually to the World Conference on Computational Intelligence}
      \resumeItemListEnd

  \resumeSubHeadingListEnd


%-----------PROJECTS-----------
\section{Projects}
    \resumeSubHeadingListStart
      \resumeProjectHeading
          {\textbf{Gitlytics} $|$ \emph{Python, Flask, React, PostgreSQL, Docker}}{June 2020 -- Present}
          \resumeItemListStart
            \resumeItem{Developed a full-stack web application using with Flask serving a REST API with React as the frontend}
            \resumeItem{Implemented GitHub OAuth to get data from user\u2019s repositories}
            \resumeItem{Visualized GitHub data to show collaboration}
            \resumeItem{Used Celery and Redis for asynchronous tasks}
          \resumeItemListEnd
      \resumeProjectHeading
          {\textbf{Simple Paintball} $|$ \emph{Spigot API, Java, Maven, TravisCI, Git}}{May 2018 -- May 2020}
          \resumeItemListStart
            \resumeItem{Developed a Minecraft server plugin to entertain kids during free time for a previous job}
            \resumeItem{Published plugin to websites gaining 2K+ downloads and an average 4.5/5-star review}
            \resumeItem{Implemented continuous delivery using TravisCI to build the plugin upon new a release}
            \resumeItem{Collaborated with Minecraft server administrators to suggest features and get feedback about the plugin}
          \resumeItemListEnd
    \resumeSubHeadingListEnd

%-----------PROGRAMMING SKILLS-----------
\section{Technical Skills}
 \begin{itemize}[leftmargin=0.15in, label={}]
    \small{\item{
     \textbf{Languages}{: Java, Python, C/C++, SQL (Postgres), JavaScript, HTML/CSS, R} \\
     \textbf{Frameworks}{: React, Node.js, Flask, JUnit, WordPress, Material-UI, FastAPI} \\
     \textbf{Developer Tools}{: Git, Docker, TravisCI, Google Cloud Platform, VS Code, Visual Studio, PyCharm, IntelliJ, Eclipse} \\
     \textbf{Libraries}{: pandas, NumPy, Matplotlib}
    }}
 \end{itemize}

\end{document}
  LATEX

  # Clean, single-column template — no color, compact spacing, small caps section titles
  MINIMAL_TEMPLATE = <<~'LATEX'
    \documentclass[letterpaper,10pt]{article}
    \usepackage[margin=0.6in]{geometry}
    \usepackage[T1]{fontenc}
    \usepackage{enumitem}
    \usepackage[hidelinks]{hyperref}
    \usepackage{titlesec}
    \usepackage{tabularx}

    \pagestyle{empty}
    \setlength{\parindent}{0pt}
    \setlength{\parskip}{4pt}
    \setlength{\tabcolsep}{0pt}
    \urlstyle{same}

    % Sections formatting
    \titleformat{\section}{
      \normalfont\scshape\large\raggedright
    }{}{0em}{}[\titlerule \vspace{-2pt}]
    \titlespacing{\section}{0pt}{10pt}{4pt}

    % Custom commands
    \newcommand{\resumeItem}[1]{\item\small{#1}}

    \newcommand{\resumeSubheading}[4]{
      \vspace{2pt}\item
      \begin{tabular*}{\textwidth}[t]{l@{\extracolsep{\fill}}r}
        \textbf{#1} & #2 \\
        \textit{\small #3} & \textit{\small #4} \\
      \end{tabular*}\vspace{-4pt}
    }

    \newcommand{\resumeProjectHeading}[2]{
      \item
      \begin{tabular*}{\textwidth}[t]{l@{\extracolsep{\fill}}r}
        \textbf{#1} & #2 \\
      \end{tabular*}\vspace{-4pt}
    }

    \newcommand{\resumeSubHeadingListStart}{\begin{list}{}{\setlength{\leftmargin}{0em}\setlength{\itemsep}{0pt}\setlength{\parsep}{0pt}\setlength{\topsep}{0pt}}}
    \newcommand{\resumeSubHeadingListEnd}{\end{list}}
    \newcommand{\resumeItemListStart}{\begin{itemize}[leftmargin=1.2em,itemsep=0pt,parsep=0pt,topsep=2pt]}
    \newcommand{\resumeItemListEnd}{\end{itemize}\vspace{-4pt}}

    %-------------------------------------------
    %%%%%%  RESUME STARTS HERE  %%%%%%%%%%%%%%%%%%%%%%%%%%%%

    \begin{document}

    %----------HEADING----------
    \begin{center}
        \textbf{\LARGE First Last} \\ \vspace{2pt}
        \small 123-456-7890 $|$ \href{mailto:email@example.com}{email} $|$
        \href{https://linkedin.com/in/...}{linkedin} $|$
        \href{https://github.com/...}{github}
    \end{center}

    \end{document}
  LATEX

  # Modern template — sans-serif with a blue accent color for headings
  MODERN_TEMPLATE = <<~'LATEX'
    \documentclass[letterpaper,10.5pt]{article}
    \usepackage[margin=0.6in]{geometry}
    \usepackage[T1]{fontenc}
    % Use the default sans-serif family (CM Sans via cm-super) so the template
    % compiles with texlive-fonts-recommended + cm-super — no extra fonts needed.
    \renewcommand{\familydefault}{\sfdefault}
    \usepackage{enumitem}
    \usepackage[hidelinks]{hyperref}
    \usepackage{titlesec}
    \usepackage{tabularx}
    \usepackage{xcolor}

    \definecolor{accent}{HTML}{2563EB}

    \pagestyle{empty}
    \setlength{\parindent}{0pt}
    \setlength{\parskip}{4pt}
    \setlength{\tabcolsep}{0pt}
    \urlstyle{same}

    % Sections formatting
    \titleformat{\section}{
      \color{accent}\normalfont\bfseries\large\raggedright
    }{}{0em}{}[{\color{accent}\titlerule} \vspace{-2pt}]
    \titlespacing{\section}{0pt}{12pt}{4pt}

    % Custom commands
    \newcommand{\resumeItem}[1]{\item\small{#1}}

    \newcommand{\resumeSubheading}[4]{
      \vspace{2pt}\item
      \begin{tabular*}{\textwidth}[t]{l@{\extracolsep{\fill}}r}
        \textbf{#1} & #2 \\
        \textit{\small #3} & \textit{\small #4} \\
      \end{tabular*}\vspace{-4pt}
    }

    \newcommand{\resumeProjectHeading}[2]{
      \item
      \begin{tabular*}{\textwidth}[t]{l@{\extracolsep{\fill}}r}
        \textbf{#1} & #2 \\
      \end{tabular*}\vspace{-4pt}
    }

    \newcommand{\resumeSubHeadingListStart}{\begin{list}{}{\setlength{\leftmargin}{0em}\setlength{\itemsep}{0pt}\setlength{\parsep}{0pt}\setlength{\topsep}{0pt}}}
    \newcommand{\resumeSubHeadingListEnd}{\end{list}}
    \newcommand{\resumeItemListStart}{\begin{itemize}[leftmargin=1.2em,itemsep=0pt,parsep=0pt,topsep=2pt]}
    \newcommand{\resumeItemListEnd}{\end{itemize}\vspace{-4pt}}

    %-------------------------------------------
    %%%%%%  RESUME STARTS HERE  %%%%%%%%%%%%%%%%%%%%%%%%%%%%

    \begin{document}

    %----------HEADING----------
    \begin{center}
        {\color{accent}\textbf{\LARGE First Last}} \\ \vspace{3pt}
        \small 123-456-7890 $|$ \href{mailto:email@example.com}{email} $|$
        \href{https://linkedin.com/in/...}{linkedin} $|$
        \href{https://github.com/...}{github}
    \end{center}

    \end{document}
  LATEX

  TEMPLATE_NOTES = {
    'jakes' => 'Use small caps (\\scshape) section headings with a thin rule underneath, serif Computer Modern fonts, and the classic single-column layout from the example.',
    'minimal' => 'Use small caps (\\scshape) section headings with a thin rule, black text only (no colors), serif Computer Modern fonts, and compact spacing to maximize content per page.',
    'modern' => 'Use the blue accent color (defined as \\color{accent}) for the name and section headings, sans-serif Helvetica body text, and clean bold section titles.'
  }.freeze

  def self.extraction_prompt(resume_content)
    <<~PROMPT
      You are a professional resume parser. Extract all relevant information from the following resume into a structured JSON format.
      Include the following fields if present:
      - name (first and last name separately)
      - contact (email, phone, location with street, city, state, zip)
      - social_media (linkedin, github, twitter, etc.)
      - education (degree, school, graduation date, GPA, relevant coursework)
      - experience (company, title, dates, location, bullet points of achievements)
      - projects (name, technologies used, bullet points of details)
      - technical_skills (categorized by: languages, developer_tools, technologies_frameworks)
      - leadership (organization, role, dates, location, bullet points of achievements)
      - awards (name, date, organization, description)
      - certifications (name, date, organization, description)
      - publications (title, date, organization, description)
      - honors (name, date, organization, description)
      - presentations (name, date, organization, description)
      - other (any other information that is not covered by the above fields)

      Format the response as valid JSON that can be parsed. Ensure all dates, locations, and other details are preserved exactly as written.
      If certain information is not present in the resume, omit those fields from the JSON rather than including empty values.

      For bullet points, preserve the exact wording but clean up any formatting issues.
      For technical skills, split them into the exact categories shown above.

      If the provided content is not a resume, return {"error": "Not a resume"}.

      Resume Content:
      #{resume_content}

      IMPORTANT: Do not include any additional text or comments in the JSON output. Do not include any ```json or ``` in the output.
      IMPORTANT: Provide ONLY the JSON output, no other text or comments.
      IMPORTANT: Any given position or activity must only be listed in a single section.
    PROMPT
  end

  def self.polishing_prompt(resume_data)
    data_json = resume_data.is_a?(String) ? resume_data : resume_data.to_json

    <<~PROMPT
      You are an expert resume polisher. Your job is to improve the following structured resume data to make it more impactful, professional, and optimized for ATS (Applicant Tracking Systems).

      Given the structured resume data below, improve it by:

      1. STRENGTHEN BULLET POINTS: Replace weak verbs with strong action verbs
         (e.g., "worked on" -> "engineered", "helped" -> "spearheaded", "was responsible for" -> "led")

      2. ADD IMPACT: Where context allows, add quantifiable achievements and results
         (e.g., "improved performance" -> "improved performance by 40%")

      3. OPTIMIZE FOR ATS: Ensure proper keyword usage for software engineering roles.
         Keep relevant technical keywords that ATS systems scan for.

      4. IMPROVE CONCISENESS: Make descriptions crisp and impactful.
         Each bullet should be 10-20 words max. Remove filler words.

      5. CONSISTENCY: Ensure all dates use the same format (e.g., "Jan 2023" or "Jan. 2023").
         Ensure consistent capitalization, punctuation.

      IMPORTANT RULES:
      - Do NOT change factual information (names, companies, dates, schools, degrees, locations)
      - Do NOT add fake metrics or achievements that aren't implied by context
      - Keep the EXACT SAME JSON structure. Do not change keys or add new ones.
      - Maximum 3 bullet points per experience/project entry
      - For education coursework, keep it to max 8 relevant items
      - If the content is already strong and well-written, make minimal changes

      Resume Data (JSON):
      #{data_json}

      Return the improved resume data in exactly the same JSON structure. No additional text.
    PROMPT
  end

  def self.latex_prompt(extracted_info, template: 'jakes')
    # Normalize to a known template so the label always matches the base template
    template = TEMPLATE_NOTES.key?(template.to_s) ? template.to_s : 'jakes'
    base_template = case template
                    when 'minimal' then MINIMAL_TEMPLATE
                    when 'modern' then MODERN_TEMPLATE
                    else JAKES_TEMPLATE
                    end
    template_note = TEMPLATE_NOTES[template]

    <<~PROMPT
      You are a LaTeX expert. Convert the following structured resume information into LaTeX using the "#{template}" template.
      Follow these specific formatting requirements and use the template code below as your base:

      Here is the #{template} resume template:
      #{base_template}

      Follow the template, maintaining all the packages, custom commands, and formatting.
      Replace only the content while keeping most of the styling and structure identical.
      You may change certain styling to fit the content, but do not change the structure of the document.
      You do not need to use all the sections, but you should use the same structure and formatting as the example.

      Styling note for this template: #{template_note}

      The final resume must fit on exactly one page. Keep only the strongest points and use concise bullets.
      Prefer 2 bullet points per job/project, and never use more than 3 bullets for any single item.
      If the content is too long, prioritize education, recent experience, strongest projects, technical skills, and honors.
      For empty content, omit the section entirely. For example, if a job has no bullet points, omit the \\resumeItemListStart and \\resumeItemListEnd.
      Ensure all content is grammatically correct and properly formatted.

      Key sections to update:
      1. Header - Replace with the provided name and contact information
      2. Education - Use the same formatting but with the provided education details
      3. Experience - Use \\resumeSubheading and \\resumeItem for each position
      4. Projects - Use \\resumeProjectHeading with the $|$ separator for technologies
      5. Technical Skills - Keep the exact same categories and formatting
      6. Awards, Certifications, Publications, Honors, Presentations - Use the same formatting as the Technical Skills section
      7. Leadership, Other - Use the same formatting as the Experience section

      Here's the resume information to format:
      #{extracted_info}

      Return only the complete LaTeX code, starting with \\documentclass and ending with \\end{document}.
      Ensure all LaTeX commands are properly escaped and the document is compilable.

      IMPORTANT: Omit non-Unicode characters from the LaTeX output.
      IMPORTANT: Escape all characters that are not allowed in LaTeX. These include: \\ { } $ % ^ ~ _ # & |
      IMPORTANT: If certain information is not present in the resume, omit those fields from the LaTeX output. Do NOT write "None" or "N/A".
      IMPORTANT: Do not include any additional text or comments in the LaTeX output. No ```latex or ``` blocks.
      IMPORTANT: Fit everything on one page. Do not create a second page.
      IMPORTANT: Provide ONLY the LaTeX output, no other text or comments.
      IMPORTANT: Any given position or activity must only be listed in a single section. Avoid repetition.
    PROMPT
  end
end
