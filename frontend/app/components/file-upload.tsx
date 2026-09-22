import { useRef, useState } from 'react';
import { Button } from '~/components/ui/button';
import { cn } from '~/lib/utils';
import { motion } from 'framer-motion';
import type { Template } from '~/lib/resumes';

interface FileUploadProps {
  isSubmitting: boolean;
  isProcessing?: boolean;
  onConvert: (file: File | null, content: string | null, template: Template) => void;
}

const TEMPLATES: { id: Template; name: string; description: string }[] = [
  { id: 'jakes', name: "Jake's", description: 'Classic serif · small caps' },
  { id: 'minimal', name: 'Minimal', description: 'Clean · compact · B&W' },
  { id: 'modern', name: 'Modern', description: 'Sans-serif · blue accents' },
];

const ACCEPTED_TYPES = [
  'application/pdf',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'text/plain',
];

export function FileUpload({ isSubmitting, isProcessing = false, onConvert }: FileUploadProps) {
  const [dragActive, setDragActive] = useState(false);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [inputMode, setInputMode] = useState<'file' | 'text'>('file');
  const [textContent, setTextContent] = useState('');
  const [template, setTemplate] = useState<Template>('jakes');
  const fileInputRef = useRef<HTMLInputElement>(null);

  const isDisabled = isSubmitting || isProcessing;

  const submitFile = (file: File) => {
    if (isDisabled) return;
    setSelectedFile(file);
    onConvert(file, null, template);
  };

  const handleDrag = (e: React.DragEvent) => {
    if (isDisabled) return;
    e.preventDefault();
    e.stopPropagation();
    if (e.type === 'dragenter' || e.type === 'dragover') {
      setDragActive(true);
    } else if (e.type === 'dragleave') {
      setDragActive(false);
    }
  };

  const handleDrop = (e: React.DragEvent) => {
    if (isDisabled) return;
    e.preventDefault();
    e.stopPropagation();
    setDragActive(false);

    const file = e.dataTransfer?.files?.[0];
    if (file && ACCEPTED_TYPES.includes(file.type)) {
      submitFile(file);
    }
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (isDisabled) return;
    const file = e.target.files?.[0];
    if (file) submitFile(file);
  };

  const handleTextSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (isDisabled || !textContent.trim()) return;
    onConvert(null, textContent, template);
  };

  return (
    <div className="space-y-5">
      {/* ─── Template picker ─── */}
      <div>
        <p className="text-sm text-gray-400 mb-2">Choose a template</p>
        <div className="flex flex-wrap gap-2 justify-center">
          {TEMPLATES.map((t) => (
            <button
              key={t.id}
              type="button"
              disabled={isDisabled}
              onClick={() => setTemplate(t.id)}
              className={cn(
                'px-4 py-2 rounded-lg border text-sm transition-colors',
                template === t.id
                  ? 'border-primary bg-primary/20 text-white'
                  : 'border-white/10 bg-white/5 text-gray-400 hover:border-white/30'
              )}
            >
              <span className="block font-medium">{t.name}</span>
              <span className="block text-[10px] opacity-70">{t.description}</span>
            </button>
          ))}
        </div>
      </div>

      {/* ─── Input mode toggle ─── */}
      <div className="flex justify-center gap-2">
        <button
          type="button"
          disabled={isDisabled}
          onClick={() => setInputMode('file')}
          className={cn(
            'px-4 py-1.5 rounded-full text-sm font-medium transition-colors',
            inputMode === 'file'
              ? 'bg-primary/20 text-white border border-primary/40'
              : 'text-gray-400 border border-white/10 hover:border-white/30'
          )}
        >
          📄 Upload File
        </button>
        <button
          type="button"
          disabled={isDisabled}
          onClick={() => setInputMode('text')}
          className={cn(
            'px-4 py-1.5 rounded-full text-sm font-medium transition-colors',
            inputMode === 'text'
              ? 'bg-primary/20 text-white border border-primary/40'
              : 'text-gray-400 border border-white/10 hover:border-white/30'
          )}
        >
          ✍️ Paste Text
        </button>
      </div>

      {/* ─── Paste-text mode ─── */}
      {inputMode === 'text' ? (
        <form
          onSubmit={handleTextSubmit}
          className="upload-zone w-full space-y-3"
        >
          <textarea
            value={textContent}
            onChange={(e) => setTextContent(e.target.value)}
            disabled={isDisabled}
            rows={10}
            placeholder="Paste your resume text here... (name, experience, education, skills, projects)"
            className="w-full bg-white/5 border border-white/10 rounded-lg p-4 text-white text-sm placeholder-gray-500 focus:outline-none focus:border-primary/50 resize-y"
          />
          <Button
            type="submit"
            disabled={isDisabled || !textContent.trim()}
            className={cn('glow-btn w-full', (isDisabled || !textContent.trim()) && 'opacity-50 cursor-not-allowed')}
          >
            {isProcessing ? 'Processing...' : isSubmitting ? 'Converting...' : 'Convert Text'}
          </Button>
        </form>
      ) : (
        /* ─── File mode ─── */
        <div
          role="button"
          tabIndex={0}
          onKeyDown={(e) => {
            if (!isDisabled && (e.key === 'Enter' || e.key === ' ')) {
              e.preventDefault();
              fileInputRef.current?.click();
            }
          }}
          className={cn(
            'upload-zone',
            !isDisabled && 'cursor-pointer hover:border-white/40',
            dragActive && 'border-primary bg-primary/10'
          )}
          onClick={() => {
            if (!isDisabled) fileInputRef.current?.click();
          }}
          onDragEnter={handleDrag}
          onDragLeave={handleDrag}
          onDragOver={handleDrag}
          onDrop={handleDrop}
        >
          <input
            ref={fileInputRef}
            type="file"
            className="hidden"
            accept=".pdf,.docx,.txt"
            onChange={handleChange}
            disabled={isDisabled}
          />

          <motion.div
            initial={{ opacity: 0, scale: 0.8 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ duration: 0.5 }}
            className="mx-auto w-16 h-16 mb-4"
          >
            <svg className="w-full h-full text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
              />
            </svg>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5, delay: 0.2 }}
            className="text-center"
          >
            {selectedFile ? (
              <div className="space-y-2">
                <p className="text-sm font-medium text-white">{selectedFile.name}</p>
                <Button
                  type="button"
                  disabled={isDisabled}
                  className={cn('glow-btn', isDisabled && 'opacity-50 cursor-not-allowed')}
                  onClick={(e) => {
                    e.stopPropagation();
                    onConvert(selectedFile, null, template);
                  }}
                >
                  {isProcessing ? 'Processing...' : isSubmitting ? 'Converting...' : 'Convert Now'}
                </Button>
              </div>
            ) : (
              <div className="space-y-2">
                <h3 className="text-xl font-semibold text-white">Drop your resume here or click to browse</h3>
                <p className="text-gray-400">Supports PDF, DOCX, and TXT files</p>
                <Button type="button" className="mt-4 glow-btn">
                  Upload Resume
                </Button>
              </div>
            )}
          </motion.div>
        </div>
      )}
    </div>
  );
}
