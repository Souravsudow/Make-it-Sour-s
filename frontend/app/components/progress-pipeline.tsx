import { useState, useEffect, useRef, useMemo } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { cn } from '~/lib/utils';

/* ─── Stage Definitions ─── */

type StageId = 'idle' | 'starting' | 'reading' | 'polishing' | 'latex' | 'done' | 'error';

interface StageInfo {
  id: StageId;
  step: number;          // Visual step index (0-4)
  progress: number;      // Percentage
  label: string;
}

const STAGE_MAP: Record<StageId, StageInfo> = {
  idle:      { id: 'idle',      step: 0, progress: 0,   label: 'Idle' },
  starting:  { id: 'starting',  step: 0, progress: 5,   label: 'Starting' },
  reading:   { id: 'reading',   step: 1, progress: 30,  label: 'Reading' },
  polishing: { id: 'polishing', step: 2, progress: 55,  label: 'Polishing' },
  latex:     { id: 'latex',     step: 3, progress: 78,  label: 'LaTeX' },
  done:      { id: 'done',      step: 4, progress: 100, label: 'Complete' },
  error:     { id: 'error',     step: -1, progress: 0,  label: 'Error' },
};

/* ─── Average seconds remaining estimates per stage ─── */
const ETA_MAP: Record<StageId, number> = {
  idle: 0,
  starting: 35,
  reading: 25,
  polishing: 15,
  latex: 8,
  done: 0,
  error: 0,
};

/**
 * Parse a backend status string into a stage.
 * Returns the stage info and a clean display message.
 */
function parseStatus(status: string): { stage: StageInfo; displayMessage: string } {
  if (!status) return { stage: STAGE_MAP.idle, displayMessage: '' };

  const s = status.trim();

  // Determine stage from the message
  let stageId: StageId;

  if (s.startsWith('Starting')) stageId = 'starting';
  else if (s.startsWith('Reading') || s.startsWith('Extracted name')) stageId = 'reading';
  else if (s.startsWith('Polishing')) stageId = 'polishing';
  else if (s.startsWith('Generating')) stageId = 'latex';
  else if (s.includes('completed') || s.includes('successfully')) stageId = 'done';
  else if (s.startsWith('Error')) stageId = 'error';
  else stageId = 'starting';

  return { stage: STAGE_MAP[stageId], displayMessage: s };
}

/* ─── Helpers ─── */

function formatTime(seconds: number): string {
  if (seconds <= 0) return '';
  if (seconds < 60) return `~${Math.round(seconds)}s remaining`;
  const m = Math.floor(seconds / 60);
  const sec = Math.round(seconds % 60);
  return `~${m}m ${sec}s remaining`;
}

/* ─── Props ─── */

interface ProgressPipelineProps {
  status: string;
  error?: string;
  className?: string;
}

/* ─── Component ─── */

export function ProgressPipeline({ status, error, className }: ProgressPipelineProps) {
  const { stage, displayMessage } = useMemo(() => parseStatus(status), [status]);
  const [elapsed, setElapsed] = useState(0);
  const [extractedName, setExtractedName] = useState<string | null>(null);
  const startRef = useRef<number | null>(null);
  const animationFrameRef = useRef<number | null>(null);

  // Extract name from status messages
  useEffect(() => {
    if (status.startsWith('Extracted name:')) {
      const name = status.replace('Extracted name:', '').trim();
      setExtractedName(name);
    }
  }, [status]);

  // Track elapsed time since processing started
  useEffect(() => {
    if (stage.id === 'starting' || stage.id === 'reading' || stage.id === 'polishing' || stage.id === 'latex') {
      if (!startRef.current) startRef.current = Date.now();

      const tick = () => {
        setElapsed(Math.floor((Date.now() - (startRef.current ?? Date.now())) / 1000));
        animationFrameRef.current = requestAnimationFrame(tick);
      };
      animationFrameRef.current = requestAnimationFrame(tick);
    } else {
      startRef.current = null;
      if (animationFrameRef.current) cancelAnimationFrame(animationFrameRef.current);
      if (stage.id === 'done' || stage.id === 'error') setElapsed(0);
    }

    return () => {
      if (animationFrameRef.current) cancelAnimationFrame(animationFrameRef.current);
    };
  }, [stage.id]);

  // ETA: use fixed estimates per stage, subtract elapsed so it counts down
  const eta = useMemo(() => {
    const base = ETA_MAP[stage.id] ?? 0;
    return Math.max(0, base - elapsed);
  }, [stage.id, elapsed]);

  // The current step index for the visual pipeline bar
  const currentStep = stage.step;

  // Determine what to show
  const isError = stage.id === 'error' || !!error;
  const isComplete = stage.id === 'done';
  const isActive = stage.id !== 'idle' && !isError && !isComplete;

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5, ease: 'easeOut' }}
      className={cn(
        'w-full max-w-xl mx-auto',
        className
      )}
    >
      <div className="relative glass-card p-6 md:p-8 overflow-hidden">
        {/* Subtle background shimmer when active */}
        {isActive && (
          <motion.div
            className="absolute inset-0 pointer-events-none"
            style={{
              background: 'linear-gradient(135deg, transparent 0%, hsl(263, 70%, 58%, 0.03) 50%, transparent 100%)',
            }}
            animate={{ x: ['-100%', '100%'] }}
            transition={{ duration: 3, repeat: Infinity, ease: 'linear' }}
          />
        )}

        {/* ─── Pipeline Steps ─── */}
        <div className="relative mb-6">
          {/* Connecting line background */}
          <div className="absolute top-4 left-0 right-0 h-[2px] bg-white/10" />

          {/* Connecting line fill */}
          <motion.div
            className="absolute top-4 left-0 h-[2px] bg-gradient-to-r from-primary via-purple-400 to-primary"
            style={{ width: `${Math.min(100, (currentStep / 4) * 100)}%` }}
            transition={{ duration: 0.6, ease: 'easeInOut' }}
          />

          {/* Step indicators */}
          <div className="relative flex justify-between">
            {[
              { step: 1, label: 'Reading', icon: '📄' },
              { step: 2, label: 'Polishing', icon: '✨' },
              { step: 3, label: 'LaTeX', icon: '📝' },
              { step: 4, label: 'Complete', icon: '✅' },
            ].map((item) => {
              const isItemActive = currentStep >= item.step;
              const isItemCurrent = currentStep === item.step;

              return (
                <div key={item.step} className="flex flex-col items-center">
                  <motion.div
                    className={cn(
                      'relative flex items-center justify-center w-8 h-8 rounded-full border-2 transition-colors duration-300 z-10',
                      isItemActive
                        ? 'border-primary bg-primary/20'
                        : 'border-white/20 bg-white/5'
                    )}
                    animate={
                      isItemCurrent
                        ? {
                            scale: [1, 1.2, 1],
                            boxShadow: [
                              '0 0 0 0 hsl(263, 70%, 58%, 0.4)',
                              '0 0 0 10px hsl(263, 70%, 58%, 0)',
                              '0 0 0 0 hsl(263, 70%, 58%, 0)',
                            ],
                          }
                        : isItemActive
                          ? { scale: 1 }
                          : { scale: 1 }
                    }
                    transition={
                      isItemCurrent
                        ? { duration: 2, repeat: Infinity, ease: 'easeOut' }
                        : { duration: 0.3 }
                    }
                  >
                    {isItemActive && currentStep > item.step ? (
                      <motion.svg
                        initial={{ scale: 0 }}
                        animate={{ scale: 1 }}
                        className="w-4 h-4 text-primary"
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth={3}
                        strokeLinecap="round"
                        strokeLinejoin="round"
                      >
                        <polyline points="20 6 9 17 4 12" />
                      </motion.svg>
                    ) : (
                      <span className={cn(
                        'text-xs font-bold',
                        isItemActive ? 'text-primary' : 'text-gray-500'
                      )}>
                        {item.step}
                      </span>
                    )}
                  </motion.div>
                  <span className={cn(
                    'mt-2 text-[11px] font-medium tracking-wide uppercase',
                    isItemActive ? 'text-white' : 'text-gray-500'
                  )}>
                    {item.label}
                  </span>
                </div>
              );
            })}
          </div>
        </div>

        {/* ─── Progress Bar ─── */}
        <div className="relative h-2 bg-white/10 rounded-full overflow-hidden mb-4">
          <motion.div
            className={cn(
              'absolute inset-y-0 left-0 rounded-full',
              isError
                ? 'bg-red-500'
                : isComplete
                  ? 'bg-green-500'
                  : 'bg-gradient-to-r from-primary to-purple-400'
            )}
            initial={{ width: '0%' }}
            animate={{ width: `${stage.progress}%` }}
            transition={{ duration: 0.8, ease: 'easeInOut' }}
          />
          {/* Shimmer overlay on active bar */}
          {isActive && (
            <motion.div
              className="absolute inset-y-0 left-0 w-20 rounded-full bg-white/20"
              animate={{ x: ['-100%', 'calc(100vw)'] }}
              transition={{ duration: 1.5, repeat: Infinity, ease: 'linear' }}
            />
          )}
        </div>

        {/* ─── Percentage ─── */}
        <div className="flex justify-between items-center mb-3">
          <span className={cn(
            'text-sm font-mono font-bold',
            isError ? 'text-red-400' : isComplete ? 'text-green-400' : 'text-primary'
          )}>
            {isError ? 'Error' : isComplete ? '100%' : `${stage.progress}%`}
          </span>
          {isActive && eta > 0 && (
            <motion.span
              key={eta}
              initial={{ opacity: 0, y: -5 }}
              animate={{ opacity: 1, y: 0 }}
              className="text-xs text-gray-400"
            >
              {formatTime(eta)}
            </motion.span>
          )}
        </div>

        {/* ─── Status Message ─── */}
        <AnimatePresence mode="wait">
          <motion.div
            key={displayMessage + (isComplete ? '-done' : '') + (isError ? '-err' : '')}
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -8 }}
            transition={{ duration: 0.3 }}
            className="min-h-[2.5rem] flex items-center gap-2"
          >
            {isActive && (
              <motion.span
                className="w-2 h-2 rounded-full bg-primary shrink-0"
                animate={{ opacity: [1, 0.3, 1] }}
                transition={{ duration: 1.5, repeat: Infinity }}
              />
            )}

            <span className={cn(
              'text-sm',
              isError ? 'text-red-300' : isComplete ? 'text-green-300' : 'text-gray-200'
            )}>
              {isError ? (error ?? displayMessage) : displayMessage}
            </span>

            {extractedName && currentStep <= 2 && !isComplete && !displayMessage.includes(extractedName) && (
              <motion.span
                initial={{ opacity: 0, scale: 0.9 }}
                animate={{ opacity: 1, scale: 1 }}
                className="ml-1 px-2 py-0.5 text-[11px] font-medium rounded-full bg-primary/20 text-primary border border-primary/30"
              >
                {extractedName}
              </motion.span>
            )}
          </motion.div>
        </AnimatePresence>

        {/* ─── Success Animation ─── */}
        {isComplete && (
          <motion.div
            initial={{ scale: 0 }}
            animate={{ scale: 1 }}
            transition={{ type: 'spring', stiffness: 200, damping: 15, delay: 0.2 }}
            className="mt-4 flex items-center gap-2 justify-center"
          >
            <div className="flex -space-x-1">
              {['🎉', '✨', '🚀', '💼'].map((emoji, i) => (
                <motion.span
                  key={emoji}
                  initial={{ y: 20, opacity: 0 }}
                  animate={{ y: 0, opacity: 1 }}
                  transition={{ delay: 0.4 + i * 0.1, type: 'spring', stiffness: 200 }}
                  className="text-lg"
                >
                  {emoji}
                </motion.span>
              ))}
            </div>
            <span className="text-sm font-medium text-green-300 ml-2">
              Your resume is ready!
            </span>
          </motion.div>
        )}

        {/* ─── Error Details ─── */}
        {isError && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: 'auto', opacity: 1 }}
            transition={{ duration: 0.3 }}
            className="mt-3 pt-3 border-t border-red-500/20"
          >
            <p className="text-xs text-red-400/70">
              Please try again. If the problem persists, check your file format or contact support.
            </p>
          </motion.div>
        )}
      </div>
    </motion.div>
  );
}
