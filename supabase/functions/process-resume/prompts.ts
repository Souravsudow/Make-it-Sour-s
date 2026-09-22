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

  return `You are an expert resume polisher. Your job is to improve the following structured resume data to make it more impactful, professional, and optimized for ATS (Applicant Tracking Systems).

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
