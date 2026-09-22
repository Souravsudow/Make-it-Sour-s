import { useLoaderData } from '@remix-run/react';
import { useState, useEffect, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { LatexOutput } from '~/components/latex-output';
import { BeforeAfter } from '~/components/before-after';
import { FileUpload } from '~/components/file-upload';
import { ProgressPipeline } from '~/components/progress-pipeline';
import { StatusMessage } from '~/components/status-message';
import { Header } from '~/components/header';
import { Footer } from '~/components/footer';
import {
  createResume,
  subscribeToResume,
  fetchResume,
  extractTextFromFile,
  type ResumeRow,
  type Template,
} from '~/lib/resumes';

export async function loader() {
  return {
    // Injected into window.ENV by root.tsx for the browser.
    SUPABASE_URL: process.env.SUPABASE_URL ?? '',
    SUPABASE_ANON_KEY: process.env.SUPABASE_ANON_KEY ?? '',
  };
}

export default function Index() {
  useLoaderData<typeof loader>();

  const [status, setStatus] = useState<string>('');
  const [requestId, setRequestId] = useState<string | null>(null);
  const [latex, setLatex] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const unsubRef = useRef<(() => void) | null>(null);

  // Handle status / completion from a resume row update.
  const handleRowUpdate = (row: ResumeRow) => {
    if (row.status) setStatus(row.status);
    if (row.latex) setLatex(row.latex);

    const s = row.status ?? '';
    if (s.includes('completed') || s.startsWith('Error')) {
      unsubRef.current?.();
      unsubRef.current = null;
    }
  };

  // Kick off processing: extract text locally, insert a row, subscribe.
  const handleConvert = async (file: File | null, content: string | null, template: Template) => {
    setIsSubmitting(true);
    setError(null);
    setLatex(null);
    setStatus('');

    try {
      let text = content;
      if (file) {
        setStatus('Extracting text from your resume...');
        text = await extractTextFromFile(file);
      }
      if (!text || !text.trim()) {
        throw new Error('Could not read any text from the provided resume.');
      }

      const id = await createResume(text, template);
      setRequestId(id);

      // The Edge Function may finish before the subscription connects —
      // fetch the row once, then subscribe for live updates.
      const existing = await fetchResume(id);
      if (existing) handleRowUpdate(existing);

      unsubRef.current?.();
      unsubRef.current = subscribeToResume(id, handleRowUpdate);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to convert resume');
      setStatus('');
    } finally {
      setIsSubmitting(false);
    }
  };

  // Cleanup subscription on unmount.
  useEffect(() => {
    return () => {
      unsubRef.current?.();
      unsubRef.current = null;
    };
  }, []);

  const isProcessing = requestId !== null && !latex && !error;

  const reset = () => {
    unsubRef.current?.();
    unsubRef.current = null;
    setLatex(null);
    setStatus('');
    setRequestId(null);
    setError(null);
  };

  return (
    <div className="min-h-screen">
      <Header />

      <main className="container mx-auto px-6 pt-8">
        <div className="mx-auto space-y-6">
          <div className="max-w-4xl mx-auto text-center">
            <motion.h1
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.5 }}
              className="font-playfair text-5xl md:text-6xl lg:text-7xl leading-tight text-white"
            >
              Improve Your Resume in{" "}
              <span className="relative inline-block">
                <span className="absolute inset-0 bg-primary/20 rounded-lg blur-sm" />
                <span className="relative px-3 py-1 text-white glow-text">One Click</span>
              </span>
            </motion.h1>

            <motion.p
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.2, duration: 0.5 }}
              className="text-xl text-gray-300 max-w-3xl mx-auto mt-4"
            >
              Transform your SWE resume into Sour&apos;s elegant LaTeX template with just one click.{' '}
              <span className="font-bold text-white">No LaTeX knowledge required</span>.
            </motion.p>
          </div>

          {!latex && (
            <div className="relative w-full max-w-5xl mx-auto text-center">
              {/* Floating Cards - LEFT */}
              <motion.div
                initial={{ opacity: 0, x: -50 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ duration: 0.5, delay: 0.3 }}
                className="absolute lg:-left-20 xl:-left-44 -top-12 w-48 h-48 hidden lg:block"
              >
                <motion.div
                  initial={{ rotate: -15 }}
                  animate={{ rotate: -10 }}
                  transition={{ duration: 0.5, delay: 0.3 }}
                  className="w-full h-full glass-card p-4 flex flex-col"
                >
                  <div className="w-8 h-8 bg-red-500/20 rounded mb-2 flex items-center justify-center">
                    <svg className="w-6 h-6 text-red-400" viewBox="0 0 24 24" fill="currentColor">
                      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8l-6-6zm4 18H6V4h7v5h5v11z" />
                    </svg>
                  </div>
                  <div className="text-xs text-white font-medium">resume.pdf</div>
                  <div className="text-[10px] text-gray-400 mt-1">2.4 MB</div>
                </motion.div>
              </motion.div>

              {/* Floating Cards - RIGHT */}
              <motion.div
                initial={{ opacity: 0, x: 50 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ duration: 0.5, delay: 0.3 }}
                className="absolute lg:-right-20 xl:-right-44 top-12 w-48 h-48 hidden lg:block"
              >
                <motion.div
                  initial={{ rotate: 15 }}
                  animate={{ rotate: 10 }}
                  transition={{ duration: 0.5, delay: 0.3 }}
                  className="w-full h-full glass-card p-4 flex flex-col"
                >
                  <div className="w-8 h-8 bg-primary/20 rounded mb-2 flex items-center justify-center">
                    <svg className="w-6 h-6 text-primary" viewBox="0 0 24 24" fill="currentColor">
                      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8l-6-6zm4 18H6V4h7v5h5v11z" />
                    </svg>
                  </div>
                  <div className="text-xs text-white font-medium">template.tex</div>
                  <div className="text-[10px] text-gray-400 mt-1">LaTeX</div>
                </motion.div>
              </motion.div>

              <div className="flex justify-center">
                <BeforeAfter />
              </div>

              <div className="mt-16 max-w-2xl mx-auto">
                <FileUpload
                  isSubmitting={isSubmitting}
                  isProcessing={isProcessing}
                  onConvert={handleConvert}
                />
              </div>
            </div>
          )}

          <AnimatePresence>
            {latex && (
              <div className="flex justify-center w-full">
                <motion.div
                  initial={{ opacity: 0, y: 20 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: -20 }}
                  className="w-full max-w-[90vw] md:max-w-4xl text-left"
                >
                  <div className="flex justify-end mb-4">
                    <button
                      onClick={reset}
                      className="text-gray-300 hover:text-white hover:bg-white/10 rounded-md px-4 py-2 text-sm"
                    >
                      Convert Another Resume
                    </button>
                  </div>
                  <LatexOutput latex={latex} personName={null} />
                </motion.div>
              </div>
            )}
          </AnimatePresence>

          <div className="text-center">
            {latex ? null : error ? (
              <StatusMessage error={error} />
            ) : status && requestId ? (
              <ProgressPipeline status={status} />
            ) : (
              <StatusMessage status={status} />
            )}
          </div>
        </div>
      </main>

      <Footer />
    </div>
  );
}
