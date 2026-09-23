/**
 * Compile LaTeX source to PDF in the browser using the free public
 * latex.ytotech.com service (LaTeX-on-HTTP). Verified working:
 * - POST /builds/sync  { compiler, resources: [{ main: true, content }] }
 *   -> 201 with PDF bytes (JSON body, ~1-3s for a one-page resume)
 * - CORS is open (echoes Origin, allows POST + content-type header)
 */

const COMPILE_ENDPOINT = 'https://latex.ytotech.com/builds/sync';

export interface CompileResult {
  blob: Blob;
  /** Object URL for the generated PDF blob. */
  url: string;
}

export class LatexCompileError extends Error {
  constructor(
    message: string,
    public readonly detail?: string
  ) {
    super(message);
    this.name = 'LatexCompileError';
  }
}

/**
 * Compile LaTeX source to a PDF blob.
 * Throws LatexCompileError on any failure (network, API, TeX errors).
 */
export async function compileLatexToPdf(
  latex: string,
  options: { compiler?: string; timeoutMs?: number } = {}
): Promise<CompileResult> {
  const { compiler = 'pdflatex', timeoutMs = 60_000 } = options;

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const resp = await fetch(COMPILE_ENDPOINT, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        compiler,
        resources: [{ main: true, content: latex }],
      }),
      signal: controller.signal,
    });

    if (!resp.ok) {
      let detail = '';
      try {
        const body = await resp.json();
        detail = body?.error ?? JSON.stringify(body).slice(0, 300);
      } catch {
        detail = `HTTP ${resp.status}`;
      }
      throw new LatexCompileError(
        'Could not compile the resume to PDF.',
        detail
      );
    }

    const blob = await resp.blob();
    if (blob.size === 0) {
      throw new LatexCompileError('PDF generation returned an empty file.');
    }
    // Basic sanity: PDF magic bytes must be present.
    const head = new Uint8Array(await blob.slice(0, 5).arrayBuffer());
    const magic = String.fromCharCode(...head);
    if (!magic.startsWith('%PDF')) {
      throw new LatexCompileError('PDF generation returned invalid data.');
    }

    return { blob, url: URL.createObjectURL(blob) };
  } catch (error) {
    if (error instanceof LatexCompileError) throw error;
    if (error instanceof DOMException && error.name === 'AbortError') {
      throw new LatexCompileError('PDF generation timed out. Please try again.');
    }
    throw new LatexCompileError(
      'Could not reach the PDF compiler. Check your connection and try again.',
      error instanceof Error ? error.message : String(error)
    );
  } finally {
    clearTimeout(timer);
  }
}
