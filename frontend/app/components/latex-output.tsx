import { useState, useMemo, useEffect, useRef } from 'react';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '~/components/ui/tabs';
import { Button } from '~/components/ui/button';
import Copy from 'lucide-react/icons/copy';
import Download from 'lucide-react/icons/download';
import ExternalLink from 'lucide-react/icons/external-link';
import FileText from 'lucide-react/icons/file-text';
import Code from 'lucide-react/icons/code';
import { cn } from '~/lib/utils';
import { Buffer } from 'buffer';
import {
  compileLatexToPdf,
  LatexCompileError,
  type CompileResult,
} from '~/lib/latex-compile';

interface LatexOutputProps {
  latex: string;
  personName?: string | null;
  className?: string;
}

export function LatexOutput({ latex, personName, className }: LatexOutputProps) {
  const [copied, setCopied] = useState(false);
  const [pdf, setPdf] = useState<CompileResult | null>(null);
  const [pdfError, setPdfError] = useState<string | null>(null);
  const [compiling, setCompiling] = useState(false);

  // Compile once per latex payload; blob URL is revoked on cleanup/retry.
  const compileSeq = useRef(0);
  useEffect(() => {
    if (!latex) return;
    const seq = ++compileSeq.current;
    let objectUrl: string | null = null;
    setCompiling(true);
    setPdfError(null);
    setPdf(null);

    compileLatexToPdf(latex)
      .then((result) => {
        if (compileSeq.current !== seq) {
          URL.revokeObjectURL(result.url);
          return;
        }
        objectUrl = result.url;
        setPdf(result);
      })
      .catch((error: unknown) => {
        if (compileSeq.current !== seq) return;
        setPdfError(
          error instanceof LatexCompileError
            ? error.message
            : 'PDF generation failed. You can still copy or download the LaTeX code.'
        );
      })
      .finally(() => {
        if (compileSeq.current === seq) setCompiling(false);
      });

    return () => {
      if (objectUrl) URL.revokeObjectURL(objectUrl);
    };
  }, [latex]);

  const handleCopy = async () => {
    await navigator.clipboard.writeText(latex);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const base64Latex = useMemo(() => {
    return Buffer.from(latex, 'utf-8').toString('base64');
  }, [latex]);

  const texFileName = personName
    ? `${personName.split(/\s+/).map((p) => p.charAt(0).toUpperCase() + p.slice(1).toLowerCase()).join('')}_Resume.tex`
    : 'resume.tex';
  const pdfFileName = texFileName.replace(/\.tex$/, '.pdf');

  const handleDownloadPdf = () => {
    if (!pdf) return;
    const a = document.createElement('a');
    a.href = pdf.url;
    a.download = pdfFileName;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
  };

  const handleDownloadTex = () => {
    const blob = new Blob([latex], { type: 'application/x-latex' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = texFileName;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

  const outlineBtn =
    'gap-1.5 border-white/10 text-white hover:bg-white/10 hover:text-white';

  return (
    <Tabs defaultValue="pdf" className={cn('w-full', className)}>
      <TabsList className="mb-4 w-full flex bg-secondary/50 p-1 rounded-lg">
        <TabsTrigger value="pdf" className="dark-tab flex-1 data-[state=active]:active">
          <FileText className="w-4 h-4 mr-1.5 inline-block" />
          Resume PDF
        </TabsTrigger>
        <TabsTrigger value="latex" className="dark-tab flex-1 data-[state=active]:active">
          <Code className="w-4 h-4 mr-1.5 inline-block" />
          LaTeX Code
        </TabsTrigger>
      </TabsList>

      {/* ─── PDF preview tab ─── */}
      <TabsContent value="pdf" className="mt-0">
        <div className="relative glass-card p-4">
          {compiling && (
            <div className="flex flex-col items-center justify-center gap-3 py-20 text-gray-300">
              <div className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin" />
              <p className="text-sm">Generating your PDF resume...</p>
            </div>
          )}

          {!compiling && pdfError && (
            <div className="flex flex-col items-center justify-center gap-3 py-16 text-center">
              <p className="text-sm text-gray-300">{pdfError}</p>
              <Button
                variant="outline"
                size="sm"
                className={outlineBtn}
                onClick={() => {
                  // Re-trigger the compile effect.
                  const key = latex;
                  compileSeq.current++;
                  setPdfError(null);
                  setCompiling(true);
                  compileLatexToPdf(key)
                    .then((result) => setPdf(result))
                    .catch(() =>
                      setPdfError(
                        'PDF generation failed. You can still copy or download the LaTeX code.'
                      )
                    )
                    .finally(() => setCompiling(false));
                }}
              >
                Try Again
              </Button>
            </div>
          )}

          {!compiling && !pdfError && pdf && (
            <>
              <div className="sticky top-0 z-10 flex justify-end gap-2 bg-secondary/50 backdrop-blur-sm py-2 px-2 rounded-t-lg -mx-4 -mt-4 mb-4">
                <form action="https://www.overleaf.com/docs" method="post" target="_blank">
                  <input
                    type="hidden"
                    name="snip_uri"
                    value={`data:application/x-tex;base64,${base64Latex}`}
                  />
                  <Button type="submit" variant="outline" size="sm" className={outlineBtn}>
                    <ExternalLink className="w-4 h-4" />
                    Overleaf
                  </Button>
                </form>
                <Button variant="outline" size="sm" className={outlineBtn} onClick={handleDownloadPdf}>
                  <Download className="w-4 h-4" />
                  Download PDF
                </Button>
              </div>
              <iframe
                src={pdf.url}
                title="Resume PDF preview"
                className="w-full h-[70vh] min-h-[500px] rounded-lg bg-white"
              />
            </>
          )}
        </div>
      </TabsContent>

      {/* ─── LaTeX code tab ─── */}
      <TabsContent value="latex" className="mt-0">
        <div className="relative glass-card">
          <div className="sticky top-0 z-10 flex justify-end gap-2 bg-secondary/50 backdrop-blur-sm py-2 px-2 rounded-t-lg">
            <form action="https://www.overleaf.com/docs" method="post" target="_blank">
              <input
                type="hidden"
                name="snip_uri"
                value={`data:application/x-tex;base64,${base64Latex}`}
              />
              <Button type="submit" variant="outline" size="sm" className={outlineBtn}>
                <ExternalLink className="w-4 h-4" />
                Open in Overleaf
              </Button>
            </form>
            <Button variant="outline" size="sm" className={outlineBtn} onClick={handleDownloadTex}>
              <Download className="w-4 h-4" />
              Download {texFileName === 'resume.tex' ? 'LaTeX' : ''}
            </Button>
            <Button variant="outline" size="sm" className={outlineBtn} onClick={handleCopy}>
              <Copy className="w-4 h-4" />
              {copied ? 'Copied!' : 'Copy'}
            </Button>
          </div>
          <pre className="bg-zinc-950 rounded-b-lg p-4 overflow-x-auto">
            <code className="text-gray-300 text-sm whitespace-pre-wrap break-words">{latex}</code>
          </pre>
        </div>
      </TabsContent>
    </Tabs>
  );
}
