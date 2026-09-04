import { type ActionFunctionArgs, json, type LoaderFunctionArgs } from '@remix-run/node';
import { useActionData, useNavigation, useLoaderData } from '@remix-run/react';
import { useState, useEffect, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { convertResume } from '~/lib/api';
import { LatexOutput } from '~/components/latex-output';
import { Button } from '~/components/ui/button';
import { Header } from '~/components/header';
import { BeforeAfter } from '~/components/before-after';
import { FileUpload } from '~/components/file-upload';
import { ProgressPipeline } from '~/components/progress-pipeline';
import { StatusMessage } from '~/components/status-message';
import { Footer } from '~/components/footer';

type ActionData = {
  latex?: string;
  error?: string;
  request_id?: string;
};

function getApiOrigin(request: Request) {
  const configuredApiUrl = process.env.API_URL || process.env.VITE_API_URL;

  if (configuredApiUrl) {
    return configuredApiUrl.replace(/\/$/, '');
  }

  const url = new URL(request.url);
  if (!url.origin.includes('localhost')) {
    url.protocol = 'https:';
  }
  return url.origin;
}

export async function loader({ request }: LoaderFunctionArgs) {
  return json({
    API_ORIGIN: getApiOrigin(request)
  });
}

export async function action({ request }: ActionFunctionArgs) {
  const formData = await request.formData();
  const file = formData.get('file') as File | null;
  const content = formData.get('content') as string | null;
  const template = (formData.get('template') as string) || 'jakes';

  if (!file && !content) {
    return json<ActionData>({ error: 'No resume provided' }, { status: 400 });
  }

  try {
    const response = await convertResume(file, content, template, getApiOrigin(request));
    return json<ActionData>({ request_id: response.request_id });
  } catch (error) {
    return json<ActionData>(
      { error: error instanceof Error ? error.message : 'Failed to convert resume' },
      { status: 500 }
    );
  }
}

export default function Index() {
  const { API_ORIGIN } = useLoaderData<typeof loader>();
  const actionData = useActionData<typeof action>();
  const navigation = useNavigation();
  const [status, setStatus] = useState<string>('');
  const [requestId, setRequestId] = useState<string | null>(null);
  const eventSourceRef = useRef<EventSource | null>(null);
  const [latex, setLatex] = useState<string | null>(null);

  useEffect(() => {
    if (actionData?.request_id) {
      setRequestId(actionData.request_id);
    }
  }, [actionData]);

  useEffect(() => {
    if (!requestId) return;

    const eventSourceUrl = new URL(`${API_ORIGIN}/api/v1/status/events`);
    eventSourceUrl.searchParams.set('request_id', requestId);

    const eventSource = new EventSource(eventSourceUrl.toString());
    eventSourceRef.current = eventSource;
    let closed = false;
    let errorCount = 0;

    const close = () => {
      if (closed) return;
      closed = true;
      eventSource.close();
      eventSourceRef.current = null;
    };

    const handleMessage = (event: MessageEvent) => {
      errorCount = 0;
      let data: { status?: string; result?: { latex?: string } };
      try {
        data = JSON.parse(event.data);
      } catch {
        setStatus('An error occurred while processing your request');
        close();
        return;
      }

      if (data.status) setStatus(data.status);

      if (data.result?.latex) {
        setLatex(data.result.latex);
      }

      if (data.status?.includes('completed') || data.status?.includes('Error')) {
        close();
      }
    };

    const handleError = () => {
      // EventSource reconnects automatically after the server's retry delay.
      // Give up only after sustained failures so we don't loop forever.
      errorCount += 1;
      if (errorCount >= 20) {
        close();
        setStatus('Connection lost. Please try again.');
      }
    };

    eventSource.addEventListener('message', handleMessage);
    eventSource.addEventListener('error', handleError);

    return () => {
      close();
      eventSource.removeEventListener('message', handleMessage);
      eventSource.removeEventListener('error', handleError);
    };
  }, [requestId, API_ORIGIN]);

  useEffect(() => {
    if (navigation.state === 'submitting') {
      setStatus('');
      setLatex(null);
      if (eventSourceRef.current) {
        eventSourceRef.current.close();
        eventSourceRef.current = null;
      }
    }
  }, [navigation.state]);

  const isSubmitting = navigation.state === 'submitting';

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
              Transform your SWE resume into Sour&apos;s elegant LaTeX template with just one click. <span className="font-bold text-white">No LaTeX knowledge required</span>.
            </motion.p>
          </div>

          {!latex && (
            <>
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
                    isProcessing={!!requestId} 
                  />
                </div>
              </div>
            </>
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
                    <Button
                      variant="ghost"
                      onClick={() => {
                        setLatex(null);
                        setStatus('');
                        setRequestId(null);
                        window.location.reload();
                      }}
                      className="text-gray-300 hover:text-white hover:bg-white/10"
                    >
                      Convert Another Resume
                    </Button>
                  </div>
                  <LatexOutput latex={latex} requestId={requestId} />
                </motion.div>
              </div>
            )}
          </AnimatePresence>

          <div className="text-center">
            {latex ? null : status && !actionData?.error ? (
              <ProgressPipeline status={status} error={actionData?.error} />
            ) : (
              <StatusMessage error={actionData?.error} status={status} />
            )}
          </div>
        </div>
      </main>

      <Footer />
    </div>
  );
}