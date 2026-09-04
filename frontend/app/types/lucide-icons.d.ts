// lucide-react ships each icon as its own ESM file at `lucide-react/icons/<name>`
// without bundled type declarations. Importing icons that way is REQUIRED for
// the Netlify function bundle — importing from the main `lucide-react` entry
// pulls in every icon eagerly and crashes with EMFILE at runtime.
declare module 'lucide-react/icons/*' {
  import type { LucideIcon } from 'lucide-react';
  const Icon: LucideIcon;
  export default Icon;
}