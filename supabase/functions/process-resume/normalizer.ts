/**
 * Resume data normalizer — ported from backend/app/services/resume_data_normalizer.rb
 */

export interface ResumeData {
  summary?: string;
  name: { first_name: string; last_name: string };
  contact_info: Record<string, string>;
  education: Record<string, unknown>[];
  experience: Record<string, unknown>[];
  projects: Record<string, unknown>[];
  technical_skills: Record<string, string[]>;
  certifications: Record<string, unknown>[];
  publications: Record<string, unknown>[];
  presentations: Record<string, unknown>[];
  honors: Record<string, unknown>[];
}

function hashValue(value: unknown): Record<string, unknown> {
  return value && typeof value === 'object' && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};
}

function cleanString(value: unknown): string {
  if (value === null || value === undefined) return '';
  if (Array.isArray(value)) {
    return value.map(cleanString).filter(Boolean).join(', ');
  }
  if (typeof value === 'object') {
    return Object.values(value as Record<string, unknown>).map(cleanString).filter(Boolean).join(', ');
  }
  return String(value).trim();
}

function stringList(value: unknown): string[] {
  if (value === null || value === undefined) return [];
  if (Array.isArray(value)) {
    return value.flatMap(stringList).map((s) => s.trim()).filter(Boolean);
  }
  if (typeof value === 'object') {
    return Object.values(value as Record<string, unknown>).flatMap(stringList).map((s) => s.trim()).filter(Boolean);
  }
  if (typeof value === 'string') {
    return value.split(/[\n;,]+/).map((s) => s.trim()).filter(Boolean);
  }
  const cleaned = cleanString(value);
  return cleaned ? [cleaned] : [];
}

function firstString(hash: Record<string, unknown>, ...keys: string[]): string {
  for (const key of keys) {
    const value = hash[key] ?? hash[`${key}`];
    const text = cleanString(value);
    if (text) return text;
  }
  return '';
}

function normalizeCollection(value: unknown): unknown[] {
  if (value === null || value === undefined) return [];
  if (Array.isArray(value)) return value.filter(Boolean);
  if (typeof value === 'object') {
    const keys = Object.keys(value as Record<string, unknown>);
    if (keys.length > 0 && keys.every((k) => /^\d+$/.test(k))) {
      return Object.values(value as Record<string, unknown>).filter(Boolean);
    }
    return [value];
  }
  if (typeof value === 'string') return value.trim() ? [value] : [];
  return [];
}

/** Type-narrowing filter — `.filter(Boolean)` doesn't narrow null away for tsc. */
function nonNull<T>(value: T | null): value is T {
  return value !== null;
}

function isEmptyEntry(data: Record<string, unknown>): boolean {
  return Object.values(data).every(
    (v) => v === null || v === undefined || (typeof v === 'string' && !v.trim()) || (Array.isArray(v) && v.length === 0)
  );
}

function normalizeName(value: unknown): { first_name: string; last_name: string } {
  if (typeof value === 'string') {
    const parts = value.trim().split(/\s+/, 2);
    return { first_name: cleanString(parts[0]), last_name: cleanString(parts[1]) };
  }
  const v = hashValue(value);
  let first = firstString(v, 'first_name', 'first', 'given_name');
  let last = firstString(v, 'last_name', 'last', 'family_name');
  const fullName = firstString(v, 'full_name', 'name');

  if (!first && !last && fullName) {
    const parts = fullName.split(/\s+/, 2);
    first = cleanString(parts[0]);
    last = cleanString(parts[1]);
  }
  return { first_name: first, last_name: last };
}

function normalizeContact(raw: Record<string, unknown>): Record<string, string> {
  const contact = {
    ...hashValue(raw['contact_info']),
    ...hashValue(raw['contact']),
    ...hashValue(raw['social_media']),
  };
  return {
    email: firstString(contact, 'email', 'mail'),
    phone: firstString(contact, 'phone', 'phone_number', 'mobile'),
    location: firstString(contact, 'location', 'address'),
    linkedin: firstString(contact, 'linkedin', 'linkedin_url'),
    github: firstString(contact, 'github', 'github_url'),
    portfolio: firstString(contact, 'portfolio', 'website', 'personal_website'),
  };
}

function normalizeEducation(entry: unknown): Record<string, unknown> | null {
  const e = hashValue(entry);
  const data = {
    school: firstString(e, 'school', 'institution', 'university', 'college'),
    degree: firstString(e, 'degree', 'program'),
    location: firstString(e, 'location'),
    graduation_date: firstString(e, 'graduation_date', 'date', 'dates', 'year'),
    gpa: firstString(e, 'gpa', 'GPA'),
    coursework: stringList(e['coursework'] ?? e['relevant_coursework']),
  };
  return isEmptyEntry(data) ? null : data;
}

function normalizeExperience(entry: unknown): Record<string, unknown> | null {
  const e = hashValue(entry);
  const data = {
    title: firstString(e, 'title', 'role', 'position'),
    company: firstString(e, 'company', 'organization', 'employer'),
    location: firstString(e, 'location'),
    dates: firstString(e, 'dates', 'date', 'duration', 'period'),
    bullets: stringList(e['bullets'] ?? e['bullet_points'] ?? e['achievements'] ?? e['responsibilities'] ?? e['description']),
  };
  return isEmptyEntry(data) ? null : data;
}

function normalizeProject(entry: unknown): Record<string, unknown> | null {
  const e = typeof entry === 'string' ? { name: entry } : hashValue(entry);
  const data = {
    name: firstString(e, 'name', 'title', 'project_name'),
    technologies: stringList(e['technologies'] ?? e['technologies_used'] ?? e['tech_stack'] ?? e['skills']),
    date: firstString(e, 'date', 'dates', 'duration', 'period'),
    bullets: stringList(e['bullets'] ?? e['bullet_points'] ?? e['details'] ?? e['description']),
  };
  return isEmptyEntry(data) ? null : data;
}

function normalizeHonor(entry: unknown): Record<string, unknown> | null {
  const e = typeof entry === 'string' ? { name: entry } : hashValue(entry);
  const data = {
    name: firstString(e, 'name', 'title', 'award', 'role'),
    organization: firstString(e, 'organization', 'issuer', 'company'),
    date: firstString(e, 'date', 'dates', 'year'),
    location: firstString(e, 'location'),
    bullets: stringList(e['bullets'] ?? e['bullet_points'] ?? e['description']),
  };
  return isEmptyEntry(data) ? null : data;
}

function normalizeSkills(value: unknown): Record<string, string[]> {
  if (value === null || value === undefined) return {};
  if (! (value instanceof Object) || Array.isArray(value)) {
    return { skills: stringList(value) };
  }
  const result: Record<string, string[]> = {};
  for (const [key, rawList] of Object.entries(value as Record<string, unknown>)) {
    const list = stringList(rawList);
    if (list.length > 0) result[key.trim()] = list;
  }
  return result;
}

export function normalize(raw: unknown): ResumeData {
  const r = hashValue(raw);
  return {
    name: normalizeName(r['name'] ?? r),
    contact_info: normalizeContact(r),
    education: normalizeCollection(r['education']).map(normalizeEducation).filter(nonNull),
    experience: normalizeCollection(r['experience']).map(normalizeExperience).filter(nonNull),
    projects: normalizeCollection(r['projects']).map(normalizeProject).filter(nonNull),
    technical_skills: normalizeSkills(r['technical_skills'] ?? r['skills']),
    // Optional summary/objective — synthesized by the polisher if absent.
    summary: cleanString(r['summary'] ?? r['objective']) || undefined,
    // Previously dropped after extraction — now preserved so the LaTeX
    // stage can render them as legitimate page-filling content.
    certifications: normalizeCollection(r['certifications']).map(normalizeHonor).filter(nonNull),
    publications: normalizeCollection(r['publications']).map(normalizeHonor).filter(nonNull),
    presentations: normalizeCollection(r['presentations']).map(normalizeHonor).filter(nonNull),
    honors: normalizeCollection(r['honors'] ?? r['leadership'] ?? r['awards']).map(normalizeHonor).filter(nonNull),
  };
}

/**
 * Light validation — ported from the JSON-schema validate! step.
 * Raises with a descriptive message if the data is unusable.
 */
export function validate(data: ResumeData): void {
  const errors: string[] = [];

  if (!data.name.first_name && !data.name.last_name) {
    errors.push('name is missing or empty');
  }
  if (!Array.isArray(data.education) || !Array.isArray(data.experience) ||
      !Array.isArray(data.projects) || !Array.isArray(data.honors)) {
    errors.push('education/experience/projects/honors must be arrays');
  }
  if (!data.contact_info || typeof data.contact_info !== 'object') {
    errors.push('contact_info must be an object');
  }
  if (!data.technical_skills || typeof data.technical_skills !== 'object') {
    errors.push('technical_skills must be an object');
  }

  if (errors.length > 0) {
    throw new Error(`Extracted resume data is invalid: ${errors.join('; ')}`);
  }
}
