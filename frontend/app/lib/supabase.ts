import { createClient } from '@supabase/supabase-js';

// window.ENV is injected by root.tsx's loader. On the server (SSR/Netlify
// function) `window` doesn't exist — guard it so the module can be imported
// during SSR without crashing. The server never *uses* the client (all DB
// calls happen in the browser), so placeholders are fine there.
const browserEnv = typeof window !== 'undefined' ? window.ENV : undefined;
const serverEnv =
  typeof process !== 'undefined'
    ? { SUPABASE_URL: process.env.SUPABASE_URL || '', SUPABASE_ANON_KEY: process.env.SUPABASE_ANON_KEY || '' }
    : { SUPABASE_URL: '', SUPABASE_ANON_KEY: '' };

const supabaseUrl = browserEnv?.SUPABASE_URL || serverEnv.SUPABASE_URL || 'https://placeholder.supabase.co';
const supabaseAnonKey = browserEnv?.SUPABASE_ANON_KEY || serverEnv.SUPABASE_ANON_KEY || 'public-anon-key';

if (typeof window !== 'undefined' && (!browserEnv?.SUPABASE_URL || !browserEnv?.SUPABASE_ANON_KEY)) {
  // Fail loudly in the browser; on Netlify the build env vars must be set.
  console.error(
    'Missing Supabase configuration. Set SUPABASE_URL and SUPABASE_ANON_KEY (root.tsx loader injects them into window.ENV).'
  );
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  realtime: { params: { eventsPerSecond: 5 } },
});
