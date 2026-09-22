import { supabase } from './supabase';

let workerSrcPromise: Promise<string> | null = null;

/** Lazily load pdf.js (code-split) and configure its worker once. */
async function loadPdfjs() {
  const [pdfjs, workerUrl] = await Promise.all([
    import('pdfjs-dist'),
    import('pdfjs-dist/build/pdf.worker.min.mjs?url').then((m) => m.default as string),
  ]);
  if (!workerSrcPromise) {
    pdfjs.GlobalWorkerOptions.workerSrc = workerUrl;
    workerSrcPromise = Promise.resolve(workerUrl);
  }
  return pdfjs;
}

export type Template = 'jakes' | 'minimal' | 'modern';

export interface ResumeRow {
  id: string;
  status: string;
  template: Template;
  latex: string | null;
  error: string | null;
  person_name: string | null;
}

export const ACCEPTED_TYPES = [
  'application/pdf',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'text/plain',
];

export const MAX_UPLOAD_BYTES = 10 * 1024 * 1024; // 10 MB
export const MAX_WORDS = 2000;

/**
 * Extract plain text from an uploaded file (PDF / DOCX / TXT).
 * Text extraction runs locally in the browser via pdf.js/mammoth —
 * the raw file never leaves the user's machine; only the extracted
 * text is stored.
 */
export async function extractTextFromFile(file: File): Promise<string> {
  if (file.size > MAX_UPLOAD_BYTES) {
    throw new Error('File too large. Maximum size is 10MB.');
  }

  if (file.type === 'text/plain') {
    return cleanText(await file.text());
  }

  if (file.type === 'application/pdf') {
    try {
      const pdfjs = await loadPdfjs();
      const buffer = await file.arrayBuffer();
      const doc = await pdfjs.getDocument({ data: buffer }).promise;
      let text = '';
      for (let i = 1; i <= doc.numPages; i++) {
        const page = await doc.getPage(i);
        const content = await page.getTextContent();
        const pageText = content.items
          .map((item) => ('str' in item ? item.str : ''))
          .join(' ');
        text += pageText + '\n';
      }
      const cleaned = cleanText(text);
      if (!cleaned) {
        throw new Error(
          'No text content found in PDF. It may be a scanned image — try a text-based PDF.'
        );
      }
      return cleaned;
    } catch (error) {
      if (error instanceof Error && error.message.includes('No text content')) throw error;
      throw new Error('Unable to read PDF file. It appears corrupted or unsupported.');
    }
  }

  if (
    file.type ===
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  ) {
    try {
      const { extractRawText } = await import('mammoth');
      const buffer = await file.arrayBuffer();
      const { value } = await extractRawText({ arrayBuffer: buffer });
      return cleanText(value);
    } catch {
      throw new Error('Unable to read DOCX file.');
    }
  }

  throw new Error('Unsupported file type. Please upload PDF, DOCX, or TXT.');
}

function cleanText(text: string): string {
  return text
    .replace(/[^\S\n]+/g, ' ') // collapse spaces/tabs, keep newlines
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

/**
 * Create the resume row. A Postgres trigger fires the process-resume
 * Edge Function via pg_net; progress arrives through Realtime.
 */
export async function createResume(
  resumeText: string,
  template: Template
): Promise<string> {
  const words = resumeText.trim().split(/\s+/).length;
  if (words === 0) throw new Error('No resume text provided');
  if (words > MAX_WORDS) {
    throw new Error(
      `Resume is too long (${words} words). Please limit to ${MAX_WORDS} words.`
    );
  }

  const { data, error } = await supabase
    .from('resumes')
    .insert({ resume_text: resumeText, template })
    .select('id')
    .single();

  if (error) throw new Error(`Failed to start processing: ${error.message}`);
  return data.id;
}

/**
 * Subscribe to realtime updates for a resume row.
 * Returns an unsubscribe function.
 */
export function subscribeToResume(
  id: string,
  onUpdate: (row: ResumeRow) => void
): () => void {
  const channel = supabase
    .channel(`resume:${id}`)
    .on(
      'postgres_changes',
      {
        event: 'UPDATE',
        schema: 'public',
        table: 'resumes',
        filter: `id=eq.${id}`,
      },
      (payload) => {
        onUpdate(payload.new as ResumeRow);
      }
    )
    .subscribe();

  return () => {
    void supabase.removeChannel(channel);
  };
}

/**
 * Fetch the current row once (handles the case where the job finished
 * before the realtime subscription connected).
 */
export async function fetchResume(id: string): Promise<ResumeRow | null> {
  const { data, error } = await supabase
    .from('resumes')
    .select('id, status, template, latex, error, person_name')
    .eq('id', id)
    .maybeSingle();

  if (error) throw new Error(`Failed to fetch resume: ${error.message}`);
  return (data as ResumeRow) ?? null;
}
