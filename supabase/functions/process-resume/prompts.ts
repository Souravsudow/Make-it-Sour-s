/**
 * Resume prompts — ported from backend/app/services/resume_prompts.rb
 */
import { getTemplate } from './templates.ts';

export function extractionPrompt(resumeContent: string): string {
  return `You are a professional resume parser. Extract all relevant information from the following resume into a structured JSON format.
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
${resumeContent}

IMPORTANT: Do not include any additional text or comments in the JSON output. Do not include any \`\`\`json or \`\`\` in the output.
IMPORTANT: Provide ONLY the JSON output, no other text or comments.
IMPORTANT: Any given position or activity must only be listed in a single section.`;
}

export function polishingPrompt(resumeData: unknown): string {
  const dataJson = typeof resumeData === 'string' ? resumeData : JSON.stringify(resumeData);

  return `You are an expert resume polisher. Your job is to enrich and improve the following structured resume data so it fills a full page with substantive, professional, ATS-optimized content.

Given the structured resume data below, improve it by:

1. STRENGTHEN BULLET POINTS: Replace weak verbs with strong action verbs
   (e.g., "worked on" -> "engineered", "helped" -> "spearheaded", "was responsible for" -> "led")

2. EXPAND EXPERIENCE BULLETS (3-4 per role):
   - Every work experience entry MUST have 3-4 bullet points. If the input only has 1-2,
     expand them by elaborating on scope of ownership, tools/technologies used, collaboration,
     and impact — all grounded in what the raw input actually says.
   - Each bullet must be detailed enough to wrap to 1.5-2 lines in a standard one-column
     resume: roughly 18-30 words. One-liner bullets are too short.
   - Follow this structure in EVERY bullet: strong action verb + what you did + how/with
     which tools + measurable or concrete outcome.
     Example shape: "Engineered a RESTful order-service using Node.js and PostgreSQL that
     cut checkout latency 35% for 10k daily users" (only if such facts exist in the input).

3. EXPAND PROJECT BULLETS (2-3 per project):
   - Each project entry MUST have 2-3 substantive bullets covering:
     (a) what was built and for whom, (b) key technical implementation details or
     architecture decisions (tools, patterns, stack), and (c) quantified outcomes/metrics
     where the input supports them (users, performance, accuracy, adoption).

4. ADD A SUMMARY SECTION:
   - If the resume data has no "summary" field, ADD one at the top level: a 2-3 line
     professional summary synthesized ONLY from the person's actual skills, education,
     experience, and projects in the data. Do not invent titles or years of experience.

5. OPTIMIZE FOR ATS: Ensure proper keyword usage for software engineering roles.
   Keep relevant technical keywords that ATS systems scan for.

6. CONSISTENCY: Ensure all dates use the same format (e.g., "Jan 2023" or "Jan. 2023").
   Ensure consistent capitalization, punctuation.

CRITICAL TRACEABILITY RULES:
- Every bullet MUST be traceable to the user's actual input. Elaborate phrasing, scope,
  and standard technical context freely — but NEVER invent companies, job titles, tools
  the person doesn't mention, employers, dates, schools, degrees, or numeric metrics.
- Numbers/metrics: only keep ones present in or directly implied by the input. If none
  exist for a bullet, end it with a concrete non-numeric outcome (e.g., "used by the
  internal support team", "adopted across the course project") instead of a made-up %.
- Do NOT change factual information (names, companies, dates, schools, degrees, locations)
- You MAY add a "summary" key if missing; otherwise keep the same JSON structure.
- For education coursework, keep it to max 8 relevant items
- If a section is already rich, keep its content but still verify the bullet structure
  and 18-30 word length guidance.

Resume Data (JSON):
${dataJson}

Return the improved resume data in exactly the same JSON structure. No additional text.`;
}

export function latexPrompt(extractedInfo: string, template: string): string {
  const { base, note } = getTemplate(template);

  return `You are a LaTeX expert. Convert the following structured resume information into LaTeX using the "${template}" template.
Follow these specific formatting requirements and use the template code below as your base:

Here is the ${template} resume template:
${base}

Follow the template, maintaining all the packages, custom commands, and formatting.
Replace only the content while keeping most of the styling and structure identical.
You may change certain styling to fit the content, but do not change the structure of the document.
You do not need to use all the sections, but you should use the same structure and formatting as the example.

Styling note for this template: ${note}

The final resume must fit on exactly one page AND fill that page visually — no large
empty gap at the bottom. Render ALL the content provided: 3-4 bullet points per work
experience entry and 2-3 bullets per project, each bullet a full detailed sentence.
If a "summary" field exists, render it as the first section under a small "Summary"
heading (2-3 lines of plain text).
Render certifications, publications, presentations, and honors entries when present.
Only if the content would overflow to a second page, trim the WEAKEST extra bullets
(last bullet of least-recent roles first), and prioritize education, recent experience,
strongest projects, technical skills, certifications, and honors.
For empty content, omit the section entirely. For example, if a job has no bullet points, omit the \\resumeItemListStart and \\resumeItemListEnd.
Ensure all content is grammatically correct and properly formatted.

Key sections to update:
1. Header - Replace with the provided name and contact information
2. Summary (if a summary field is present) - A short section with 2-3 lines of plain text
3. Education - Use the same formatting but with the provided education details
4. Experience - Use \\resumeSubheading and \\resumeItem for each position, with 3-4 \\resumeItem entries
5. Projects - Use \\resumeProjectHeading with the $|$ separator for technologies, with 2-3 \\resumeItem entries
6. Technical Skills - Keep the exact same categories and formatting
7. Certifications, Publications, Honors, Presentations - Use the same formatting as the Technical Skills section when the data includes them
8. Leadership, Other - Use the same formatting as the Experience section

Here's the resume information to format:
${extractedInfo}

Return only the complete LaTeX code, starting with \\documentclass and ending with \\end{document}.
Ensure all LaTeX commands are properly escaped and the document is compilable.

IMPORTANT: Omit non-Unicode characters from the LaTeX output.
IMPORTANT: Escape all characters that are not allowed in LaTeX. These include: \\ { } $ % ^ ~ _ # & |
IMPORTANT: If certain information is not present in the resume, omit those fields from the LaTeX output. Do NOT write "None" or "N/A".
IMPORTANT: Do not include any additional text or comments in the LaTeX output. No \`\`\`latex or \`\`\` blocks.
IMPORTANT: Fit everything on one page. Do not create a second page.
IMPORTANT: Provide ONLY the LaTeX output, no other text or comments.
IMPORTANT: Any given position or activity must only be listed in a single section. Avoid repetition.`;
}
