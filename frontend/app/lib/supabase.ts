import { createClient, type SupabaseClient } from '@supabase/supabase-js';

// The Supabase client is browser-only in this app (all DB calls happen
// client-side). Creating it at module scope used to crash the Netlify SSR
// function twice: first on `window`, then because supabase-js initializes
// Realtime, which needs a native WebSocket that Node 20 lacks. So the
// client is now created lazily, only inside the browser.
let client: SupabaseClient | null = null;

export function getSupabase(): SupabaseClient {
  if (typeof window === 'undefined') {
    throw new Error('Supabase client is browser-only; do not call getSupabase() during SSR.');
  }

  if (!client) {
    const url = window.ENV?.SUPABASE_URL || process.env.SUPABASE_URL || '';
    const key = window.ENV?.SUPABASE_ANON_KEY || process.env.SUPABASE_ANON_KEY || '';

    if (!url || !key) {
      console.error(
        'Missing Supabase configuration. Set SUPABASE_URL and SUPABASE_ANON_KEY (root.tsx loader injects them into window.ENV).'
      );
    }

    client = createClient(url || 'https://placeholder.supabase.co', key || 'public-anon-key', {
      realtime: { params: { eventsPerSecond: 5 } },
    });
  }

  return client;
}
