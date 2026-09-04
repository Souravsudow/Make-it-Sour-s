import { useRef, useState } from 'react';
import { Form, useSubmit } from '@remix-run/react';
import { Button } from '~/components/ui/button';
import { cn } from '~/lib/utils';
import { motion } from 'framer-motion';

interface FileUploadProps {
  isSubmitting: boolean;
  isProcessing?: boolean;
}

const TEMPLATES = [
  { id: 'jakes', name: "Jake's", description: 'Classic serif · small caps' },
  { id: 'minimal', name: 'Minimal', description: 'Clean · compact · B&W' },
  { id: 'modern', name: 'Modern', description: 'Sans-serif · blue accents' },
];

const ACCEPTED_TYPES = [
  'application/pdf',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'text/plain',
];

export function FileUpload({ isSubmitting, isProcessing = false }: FileUploadProps) {
  const [dragActive, setDragActive] = useState(false);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [inputMode, setInputMode] = useState<'file' | 'text'>('file');
  const [textContent, setTextContent] = useState('');
  const [template, setTemplate] = useState('jakes');
  const formRef = useRef<HTMLFormElement>(null);
  const submit = useSubmit();

  const isDisabled = isSubmitting || isProcessing;

  const submitFormData = (formData: FormData) => {
    if (isDisabled) return;
    submit(formData, { method: 'post', encType: 'multipart/form-data' });
  };

  const buildFormData = (): FormData | null => {
    const formData = new FormData();
    formData.append('template', template);

    if (inputMode === 'text') {
      if (!textContent.trim()) return null;
      formData.append('content', textContent);
    } else {
      if (!selectedFile) return null;
      formData.append('file', selectedFile);
    }
    return formData;
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const formData = buildFormData();
    if (formData) submitFormData(formData);
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
      setSelectedFile(file);
      const formData = new FormData();
      formData.append('file', file);
      formData.append('template', template);
      submitFormData(formData);
    }
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (isDisabled) return;
    const file = e.target.files?.[0];
    if (file) {
      setSelectedFile(file);
      const formData = new FormData();
      formData.append('file', file);
      formData.append('template', template);
      submitFormData(formData);
    }
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

      <Form
        ref={formRef}
        method="post"
        encType="multipart/form-data"
        onSubmit={handleSubmit}
        className={cn(
          'upload-zone',
          !isDisabled && 'cursor-pointer hover:border-white/40',
          dragActive && 'border-primary bg-primary/10'
        )}
        onClick={() => {
          if (!isDisabled && inputMode === 'file') {
            const fileInput = formRef.current?.querySelector('input[type="file"]') as HTMLInputElement;
            fileInput?.click();
          }
        }}
        onDragEnter={handleDrag}
        onDragLeave={handleDrag}
        onDragOver={handleDrag}
        onDrop={handleDrop}
      >
        <input
          type="file"
          name="file"
          className="hidden"
          accept=".pdf,.doc,.docx,.txt"
          onChange={handleChange}
          disabled={isDisabled}
        />

        {inputMode === 'text' ? (
          <div className="w-full space-y-3">
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
              onClick={(e) => e.stopPropagation()}
            >
              {isProcessing ? 'Processing...' : isSubmitting ? 'Converting...' : 'Convert Text'}
            </Button>
          </div>
        ) : (
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
        )}

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, delay: 0.2 }}
          className="text-center"
        >
          {inputMode === 'file' ? (
            selectedFile ? (
              <div className="space-y-2">
                <p className="text-sm font-medium text-white">{selectedFile.name}</p>
                <Button
                  type="submit"
                  disabled={isDisabled}
                  className={cn('glow-btn', isDisabled && 'opacity-50 cursor-not-allowed')}
                  onClick={(e) => e.stopPropagation()}
                >
                  {isProcessing ? 'Processing...' : isSubmitting ? 'Converting...' : 'Convert Now'}
                </Button>
              </div>
            ) : (
              <div className="space-y-2">
                <h3 className="text-xl font-semibold text-white">Drop your resume here or click to browse</h3>
                <p className="text-gray-400">Supports PDF, DOC, DOCX, and TXT files</p>
                <Button type="button" className="mt-4 glow-btn">
                  Upload Resume
                </Button>
              </div>
            )
          ) : null}
        </motion.div>
      </Form>
    </div>
  );
}