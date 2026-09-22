import { useState, useMemo } from 'react';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '~/components/ui/tabs';
import { Button } from '~/components/ui/button';
import Copy from 'lucide-react/icons/copy';
import Download from 'lucide-react/icons/download';
import ExternalLink from 'lucide-react/icons/external-link';
import { cn } from '~/lib/utils';
import { Buffer } from 'buffer';

interface LatexOutputProps {
  latex: string;
  personName?: string | null;
  className?: string;
}

export function LatexOutput({ latex, personName, className }: LatexOutputProps) {
  const [copied, setCopied] = useState(false);

  const handleCopy = async () => {
    await navigator.clipboard.writeText(latex);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleDownload = () => {
    const blob = new Blob([latex], { type: 'application/x-latex' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'resume.tex';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

  const base64Latex = useMemo(() => {
    return Buffer.from(latex, 'utf-8').toString('base64');
  }, [latex]);

  const texFileName = personName
    ? `${personName.split(/\s+/).map((p) => p.charAt(0).toUpperCase() + p.slice(1).toLowerCase()).join('')}_Resume.tex`
    : 'resume.tex';

  return (
    <Tabs defaultValue="latex" className={cn('w-full', className)}>
      <TabsList className="mb-4 w-full flex bg-secondary/50 p-1 rounded-lg">
        <TabsTrigger value="latex" className="dark-tab flex-1 data-[state=active]:active">
          LaTeX Code
        </TabsTrigger>
      </TabsList>

      <TabsContent value="latex" className="mt-0">
        <div className="relative glass-card">
          <div className="sticky top-0 z-10 flex justify-end gap-2 bg-secondary/50 backdrop-blur-sm py-2 px-2 rounded-t-lg">
            <form action="https://www.overleaf.com/docs" method="post" target="_blank">
              <input type="hidden" name="snip_uri" value={`data:application/x-tex;base64,${base64Latex}`} />
              <Button
                type="submit"
                variant="outline"
                size="sm"
                className="gap-1.5 border-white/10 text-white hover:bg-white/10 hover:text-white"
              >
                <ExternalLink className="w-4 h-4" />
                Open in Overleaf
              </Button>
            </form>
            <Button
              variant="outline"
              size="sm"
              className="gap-1.5 border-white/10 text-white hover:bg-white/10 hover:text-white"
              onClick={handleDownload}
            >
              <Download className="w-4 h-4" />
              Download {texFileName === 'resume.tex' ? 'LaTeX' : ''}
            </Button>
            <Button
              variant="outline"
              size="sm"
              className="gap-1.5 border-white/10 text-white hover:bg-white/10 hover:text-white"
              onClick={handleCopy}
            >
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
