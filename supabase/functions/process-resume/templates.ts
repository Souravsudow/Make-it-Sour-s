/**
 * LaTeX base templates — ported from backend/app/services/resume_prompts.rb
 */

export const JAKES_TEMPLATE = `\\documentclass[letterpaper,11pt]{article}

\\usepackage{latexsym}
\\usepackage[empty]{fullpage}
\\usepackage{titlesec}
\\usepackage{marvosym}
\\usepackage[usenames,dvipsnames]{color}
\\usepackage{verbatim}
\\usepackage{enumitem}
\\usepackage[hidelinks]{hyperref}
\\usepackage{fancyhdr}
\\usepackage[english]{babel}
\\usepackage{tabularx}
\\input{glyphtounicode}

\\pagestyle{fancy}
\\fancyhf{}
\\fancyfoot{}
\\renewcommand{\\headrulewidth}{0pt}
\\renewcommand{\\footrulewidth}{0pt}

\\addtolength{\\oddsidemargin}{-0.5in}
\\addtolength{\\evensidemargin}{-0.5in}
\\addtolength{\\textwidth}{1in}
\\addtolength{\\topmargin}{-.5in}
\\addtolength{\\textheight}{1.0in}

\\urlstyle{same}
\\raggedbottom
\\raggedright
\\setlength{\\tabcolsep}{0in}

\\titleformat{\\section}{
  \\vspace{-4pt}\\scshape\\raggedright\\large
}{}{0em}{}[\\color{black}\\titlerule \\vspace{-5pt}]

\\pdfgentounicode=1

\\newcommand{\\resumeItem}[1]{
  \\item\\small{
    {#1 \\vspace{-2pt}}
  }
}

\\newcommand{\\resumeSubheading}[4]{
  \\vspace{-2pt}\\item
    \\begin{tabular*}{0.97\\textwidth}[t]{l@{\\extracolsep{\\fill}}r}
      \\textbf{#1} & #2 \\\\
      \\textit{\\small#3} & \\textit{\\small #4} \\\\
    \\end{tabular*}\\vspace{-7pt}
}

\\newcommand{\\resumeSubSubheading}[2]{
    \\item
    \\begin{tabular*}{0.97\\textwidth}{l@{\\extracolsep{\\fill}}r}
      \\textit{\\small#1} & \\textit{\\small #2} \\\\
    \\end{tabular*}\\vspace{-7pt}
}

\\newcommand{\\resumeProjectHeading}[2]{
    \\item
    \\begin{tabular*}{0.97\\textwidth}{l@{\\extracolsep{\\fill}}r}
      \\small#1 & #2 \\\\
    \\end{tabular*}\\vspace{-7pt}
}

\\newcommand{\\resumeSubItem}[1]{\\resumeItem{#1}\\vspace{-4pt}}

\\renewcommand\\labelitemii{$\\vcenter{\\hbox{\\tiny$\\bullet$}}$}

\\newcommand{\\resumeSubHeadingListStart}{\\begin{list}{}{\\setlength{\\leftmargin}{0.15in}\\setlength{\\itemsep}{0pt}\\setlength{\\parsep}{0pt}\\setlength{\\topsep}{0pt}}}
\\newcommand{\\resumeSubHeadingListEnd}{\\end{list}}
\\newcommand{\\resumeItemListStart}{\\begin{itemize}}
\\newcommand{\\resumeItemListEnd}{\\end{itemize}\\vspace{-5pt}}

\\begin{document}

\\begin{center}
    \\textbf{\\Huge \\scshape Jake Ryan} \\\\ \\vspace{1pt}
    \\small 123-456-7890 $|$ \\href{mailto:x@x.com}{\\underline{jake@su.edu}} $|$
    \\href{https://linkedin.com/in/...}{\\underline{linkedin.com/in/jake}} $|$
    \\href{https://github.com/...}{\\underline{github.com/jake}}
\\end{center}

\\section{Education}
  \\resumeSubHeadingListStart
    \\resumeSubheading
      {Southwestern University}{Georgetown, TX}
      {Bachelor of Arts in Computer Science, Minor in Business}{Aug. 2018 -- May 2021}
  \\resumeSubHeadingListEnd

\\section{Experience}
  \\resumeSubHeadingListStart
    \\resumeSubheading
      {Undergraduate Research Assistant}{June 2020 -- Present}
      {Texas A\\&M University}{College Station, TX}
      \\resumeItemListStart
        \\resumeItem{Developed a REST API using FastAPI and PostgreSQL to store data from learning management systems}
        \\resumeItem{Developed a full-stack web application using Flask, React, PostgreSQL and Docker to analyze GitHub data}
      \\resumeItemListEnd
  \\resumeSubHeadingListEnd

\\section{Projects}
    \\resumeSubHeadingListStart
      \\resumeProjectHeading
          {\\textbf{Gitlytics} $|$ \\emph{Python, Flask, React, PostgreSQL, Docker}}{June 2020 -- Present}
          \\resumeItemListStart
            \\resumeItem{Developed a full-stack web application using with Flask serving a REST API with React as the frontend}
            \\resumeItem{Used Celery and Redis for asynchronous tasks}
          \\resumeItemListEnd
    \\resumeSubHeadingListEnd

\\section{Technical Skills}
 \\begin{itemize}[leftmargin=0.15in, label={}]
    \\small{\\item{
     \\textbf{Languages}{: Java, Python, C/C++, SQL (Postgres), JavaScript} \\\\
     \\textbf{Frameworks}{: React, Node.js, Flask, FastAPI} \\\\
     \\textbf{Developer Tools}{: Git, Docker, VS Code} \\\\
    }}
 \\end{itemize}

\\end{document}`;

export const MINIMAL_TEMPLATE = `\\documentclass[letterpaper,10pt]{article}
\\usepackage[margin=0.6in]{geometry}
\\usepackage[T1]{fontenc}
\\usepackage{enumitem}
\\usepackage[hidelinks]{hyperref}
\\usepackage{titlesec}
\\usepackage{tabularx}

\\pagestyle{empty}
\\setlength{\\parindent}{0pt}
\\setlength{\\parskip}{4pt}
\\setlength{\\tabcolsep}{0pt}
\\urlstyle{same}

\\titleformat{\\section}{
  \\normalfont\\scshape\\large\\raggedright
}{}{0em}{}[\\titlerule \\vspace{-2pt}]
\\titlespacing{\\section}{0pt}{10pt}{4pt}

\\newcommand{\\resumeItem}[1]{\\item\\small{#1}}

\\newcommand{\\resumeSubheading}[4]{
  \\vspace{2pt}\\item
  \\begin{tabular*}{\\textwidth}[t]{l@{\\extracolsep{\\fill}}r}
    \\textbf{#1} & #2 \\\\
    \\textit{\\small #3} & \\textit{\\small #4} \\\\
  \\end{tabular*}\\vspace{-4pt}
}

\\newcommand{\\resumeProjectHeading}[2]{
  \\item
  \\begin{tabular*}{\\textwidth}[t]{l@{\\extracolsep{\\fill}}r}
    \\textbf{#1} & #2 \\\\
  \\end{tabular*}\\vspace{-4pt}
}

\\newcommand{\\resumeSubHeadingListStart}{\\begin{list}{}{\\setlength{\\leftmargin}{0em}\\setlength{\\itemsep}{0pt}\\setlength{\\parsep}{0pt}\\setlength{\\topsep}{0pt}}}
\\newcommand{\\resumeSubHeadingListEnd}{\\end{list}}
\\newcommand{\\resumeItemListStart}{\\begin{itemize}[leftmargin=1.2em,itemsep=0pt,parsep=0pt,topsep=2pt]}
\\newcommand{\\resumeItemListEnd}{\\end{itemize}\\vspace{-4pt}}

\\begin{document}

\\begin{center}
    \\textbf{\\LARGE First Last} \\\\ \\vspace{2pt}
    \\small 123-456-7890 $|$ \\href{mailto:email@example.com}{email} $|$
    \\href{https://linkedin.com/in/...}{linkedin} $|$
    \\href{https://github.com/...}{github}
\\end{center}

\\end{document}`;

export const MODERN_TEMPLATE = `\\documentclass[letterpaper,10.5pt]{article}
\\usepackage[margin=0.6in]{geometry}
\\usepackage[T1]{fontenc}
\\renewcommand{\\familydefault}{\\sfdefault}
\\usepackage{enumitem}
\\usepackage[hidelinks]{hyperref}
\\usepackage{titlesec}
\\usepackage{tabularx}
\\usepackage{xcolor}

\\definecolor{accent}{HTML}{2563EB}

\\pagestyle{empty}
\\setlength{\\parindent}{0pt}
\\setlength{\\parskip}{4pt}
\\setlength{\\tabcolsep}{0pt}
\\urlstyle{same}

\\titleformat{\\section}{
  \\color{accent}\\normalfont\\bfseries\\large\\raggedright
}{}{0em}{}[{\\color{accent}\\titlerule} \\vspace{-2pt}]
\\titlespacing{\\section}{0pt}{12pt}{4pt}

\\newcommand{\\resumeItem}[1]{\\item\\small{#1}}

\\newcommand{\\resumeSubheading}[4]{
  \\vspace{2pt}\\item
  \\begin{tabular*}{\\textwidth}[t]{l@{\\extracolsep{\\fill}}r}
    \\textbf{#1} & #2 \\\\
    \\textit{\\small #3} & \\textit{\\small #4} \\\\
  \\end{tabular*}\\vspace{-4pt}
}

\\newcommand{\\resumeProjectHeading}[2]{
  \\item
  \\begin{tabular*}{\\textwidth}[t]{l@{\\extracolsep{\\fill}}r}
    \\textbf{#1} & #2 \\\\
  \\end{tabular*}\\vspace{-4pt}
}

\\newcommand{\\resumeSubHeadingListStart}{\\begin{list}{}{\\setlength{\\leftmargin}{0em}\\setlength{\\itemsep}{0pt}\\setlength{\\parsep}{0pt}\\setlength{\\topsep}{0pt}}}
\\newcommand{\\resumeSubHeadingListEnd}{\\end{list}}
\\newcommand{\\resumeItemListStart}{\\begin{itemize}[leftmargin=1.2em,itemsep=0pt,parsep=0pt,topsep=2pt]}
\\newcommand{\\resumeItemListEnd}{\\end{itemize}\\vspace{-4pt}}

\\begin{document}

\\begin{center}
    {\\color{accent}\\textbf{\\LARGE First Last}} \\\\ \\vspace{3pt}
    \\small 123-456-7890 $|$ \\href{mailto:email@example.com}{email} $|$
    \\href{https://github.com/...}{github}
\\end{center}

\\end{document}`;

export const TEMPLATE_NOTES: Record<string, string> = {
  jakes:
    'Use small caps (\\scshape) section headings with a thin rule underneath, serif Computer Modern fonts, and the classic single-column layout from the example.',
  minimal:
    'Use small caps (\\scshape) section headings with a thin rule, black text only (no colors), serif Computer Modern fonts, and compact spacing to maximize content per page.',
  modern:
    'Use the blue accent color (defined as \\color{accent}) for the name and section headings, sans-serif Helvetica body text, and clean bold section titles.',
};

export function getTemplate(template: string): { base: string; note: string } {
  switch (template) {
    case 'minimal':
      return { base: MINIMAL_TEMPLATE, note: TEMPLATE_NOTES.minimal };
    case 'modern':
      return { base: MODERN_TEMPLATE, note: TEMPLATE_NOTES.modern };
    default:
      return { base: JAKES_TEMPLATE, note: TEMPLATE_NOTES.jakes };
  }
}
