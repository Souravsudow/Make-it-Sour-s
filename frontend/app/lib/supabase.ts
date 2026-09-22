import { createClient } from '@supabase/supabase-js';

// window.ENV is injected by root.tsx's loader (server reads process.env).
// The typeof guards keep the browser bundle from touching `process`.
const supabaseUrl =
  window.ENV?.SUPABASE_URL ||
  (typeof process !== 'undefined' ? process.env.SUPABASE_URL || '' : '');
const supabaseAnonKey =
  window.ENV?.SUPABASE_ANON_KEY ||
  (typeof process !== 'undefined' ? process.env.SUPABASE_ANON_KEY || '' : '');

if (!supabaseUrl || !supabaseAnonKey) {
  // Fail loudly in dev; on Netlify the build env vars must be set.
  console.error(
    'Missing Supabase configuration. Set SUPABASE_URL and SUPABASE_ANON_KEY (root.tsx loader injects them into window.ENV).'
  );
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  realtime: { params: { eventsPerSecond: 5 } },
});
