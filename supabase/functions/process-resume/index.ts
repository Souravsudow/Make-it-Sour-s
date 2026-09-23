// Supabase Edge Function: process-resume
// Replaces Rails ResumeProcessingJob + ResumePipelineService + Sidekiq.
//
// Triggered by a Postgres webhook (pg_net) when a new row is inserted
// into public.resumes. Runs the 3-stage Groq pipeline (extract → polish
// → LaTeX) and updates the row; Realtime pushes updates to the browser.
//
// Required secrets (supabase secrets set):
//   GROQ_API_KEY  (or GROQ_API_KEY_READER / _POLISHER / _LATEX + variants)
//   SUPABASE_URL  (auto-injected on Supabase, set manually elsewhere)

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { extractionPrompt, polishingPrompt, latexPrompt } from './prompts.ts';
import { normalize, validate, type ResumeData } from './normalizer.ts';
import {
  STAGE_CONFIGS,
  resolveApiKeys,
  resolveModels,
  extractErrorMessage,
  isKeyRotationError,
  isRetryableError,
  friendlyError,
  cleanOutput,
  type Stage,
} from './groq.ts';

const GROQ_API_BASE = 'https://api.groq.com/openai/v1/chat/completions';
const MAX_WORDS = 2000;

interface ResumeRow {
  id: string;
  template: string;
  resume_text: string;
}

interface WebhookPayload {
  type: string;
  table: string;
  record: { id: string };
}

// ─── Groq call with key rotation + model fallback (port of make_request) ───

async function groqRequest(stage: Stage, prompt: string): Promise<string> {
  const config = STAGE_CONFIGS[stage];
  const apiKeys = resolveApiKeys(stage);
  const models = resolveModels(stage);

  let lastStatus = 0;
  let lastMessage = 'no attempts made';

  for (const apiKey of apiKeys) {
    for (const model of models) {
      const body: Record<string, unknown> = {
        model,
        messages: [{ role: 'user', content: prompt }],
        max_tokens: config.maxTokens,
        temperature: config.temperature,
      };
      if (config.jsonMode) {
        body.response_format = { type: 'json_object' };
      }

      try {
        const resp = await fetch(GROQ_API_BASE, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${apiKey}`,
          },
          body: JSON.stringify(body),
        });

        if (!resp.ok) {
          const errBody = await resp.json().catch(() => null);
          lastStatus = resp.status;
          lastMessage = extractErrorMessage(errBody);

          if (isKeyRotationError(resp.status, lastMessage)) {
            console.warn(`Groq ${stage}: key failed (${resp.status}): ${lastMessage}`);
            break; // next key
          }
          if (isRetryableError(resp.status, lastMessage)) {
            console.warn(`Groq ${stage}: model ${model} retryable error (${resp.status}): ${lastMessage}`);
            continue; // next model
          }
          throw new Error(friendlyError(stage, resp.status, lastMessage));
        }

        const data = await resp.json();
        const choices = data?.choices ?? [];
        if (choices.length === 0) {
          lastMessage = 'empty choices array';
          throw new Error(`Groq ${stage}: empty response`);
        }

        return cleanOutput(choices[0]?.message?.content ?? '');
      } catch (error) {
        // Friendly errors (starting with "Groq ") are final — rethrow.
        if (error instanceof Error && error.message.startsWith('Groq ')) throw error;
        lastMessage = `network error: ${error instanceof Error ? error.message : String(error)}`;
        console.warn(`Groq ${stage}: ${lastMessage}`);
      }
    }
  }

  throw new Error(
    `Groq ${stage}: all attempts failed (last status ${lastStatus}): ${lastMessage}`
  );
}

// ─── Pipeline ───────────────────────────────────────────────────────────────

async function runPipeline(row: ResumeRow): Promise<void> {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    { auth: { persistSession: false } }
  );
  const id = row.id;

  async function update(fields: Record<string, unknown>) {
    const { error } = await supabase.from('resumes').update(fields).eq('id', id);
    if (error) throw new Error(`DB update failed: ${error.message}`);
  }

  try {
    await update({ status: 'Reading and extracting structured data from your resume...' });

    // Word-count guard (port of validate_word_count!)
    const wordCount = row.resume_text.trim().split(/\s+/).length;
    if (wordCount > MAX_WORDS) {
      throw new Error(`Resume is too long (${wordCount} words). Please limit to ${MAX_WORDS} words.`);
    }

    // ── Stage 1: READER ──
    const extractedRaw = await groqRequest('reader', extractionPrompt(row.resume_text));
    let extracted: unknown;
    try {
      extracted = JSON.parse(extractedRaw);
    } catch {
      throw new Error(`Failed to extract resume details: invalid JSON from model`);
    }
    if (extracted && typeof extracted === 'object' && 'error' in (extracted as object)) {
      throw new Error(String((extracted as { error: unknown }).error));
    }

    const normalized = normalize(extracted);
    validate(normalized as ResumeData);

    // Dev diagnostic: when the resume is thin (few projects), surface user
    // data that WAS extracted but never reaches the template — those sections
    // could be rendered to fill the page legitimately. Check the logs:
    // `supabase functions logs process-resume`.
    if (normalized.projects.length < 3) {
      // Map each raw extraction key to where normalize() outputs it.
      // 'other' has no destination, so any content there is always unused.
      const destinations: Record<string, unknown> = {
        certifications: normalized.certifications,
        publications: normalized.publications,
        presentations: normalized.presentations,
        awards: normalized.honors,
        achievements: normalized.honors,
        other: [], // never normalized — always a candidate
      };
      const raw = extracted as Record<string, unknown>;
      const unused = Object.keys(destinations).filter((key) => {
        const rawVal = raw[key];
        const hasRaw = Array.isArray(rawVal)
          ? rawVal.length > 0
          : Boolean(rawVal && String(rawVal).trim());
        if (!hasRaw) return false;
        const dest = destinations[key];
        return !Array.isArray(dest) || dest.length === 0;
      });
      if (unused.length > 0) {
        console.warn(
          `[process-resume ${id}] Only ${normalized.projects.length} projects — ` +
          `extracted but unused content sections: ${unused.join(', ')}. ` +
          `Consider rendering them in the template to add legitimate content.`
        );
      }
    }

    const name = normalized.name;
    const personName = [name.first_name, name.last_name].filter(Boolean).join(' ') || null;
    await update({
      status: `Extracted name: ${personName ?? 'Unknown'}`,
      extracted: normalized,
      person_name: personName,
    });

    // ── Stage 2: POLISHER (falls back to original data on failure) ──
    await update({ status: 'Polishing and strengthening your resume content...' });
    let polished: ResumeData = normalized;
    try {
      const polishedRaw = await groqRequest('polisher', polishingPrompt(normalized));
      const parsed = JSON.parse(polishedRaw) as ResumeData;
      validate(parsed);
      polished = parsed;
    } catch (error) {
      console.warn(`Polishing failed, using original data: ${error instanceof Error ? error.message : error}`);
    }

    // ── Stage 3: LATEX ──
    await update({ status: 'Generating professional LaTeX resume...' });
    const latex = await groqRequest('latex', latexPrompt(JSON.stringify(polished), row.template));

    await update({
      status: 'Resume formatting completed successfully!',
      polished,
      latex,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error(`Pipeline error for ${id}: ${message}`);
    await update({ status: `Error: ${message}`, error: message }).catch((e) =>
      console.error(`Failed to record error state: ${e}`)
    );
  }
}

// ─── HTTP handler ───────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  // Verify the request came from Supabase (service role JWT) — prevents
  // random internet traffic from triggering the pipeline.
  const authHeader = req.headers.get('Authorization') ?? '';
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
  if (!authHeader.endsWith(serviceKey)) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  let payload: { record?: { id?: string }; id?: string };
  try {
    payload = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON payload' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // The pg_net trigger sends only { record: { id } } — the function fetches
  // the full row itself (smaller webhook payload, always fresh data).
  const id = payload?.record?.id ?? payload?.id;
  if (!id) {
    return new Response(JSON.stringify({ error: 'Missing record id' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // Fire-and-forget so pg_net's 5s timeout never kills a long pipeline.
  // EdgeRuntime.waitUntil keeps the isolate alive after we return 202.
  EdgeRuntime.waitUntil(
    (async () => {
      try {
        const admin = createClient(
          Deno.env.get('SUPABASE_URL') ?? '',
          Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
          { auth: { persistSession: false } }
        );
        const { data: row, error } = await admin
          .from('resumes')
          .select('id, template, resume_text')
          .eq('id', id)
          .maybeSingle();
        if (error || !row) {
          console.error(`Could not load resume row ${id}: ${error?.message ?? 'not found'}`);
          return;
        }
        await runPipeline({
          id: row.id,
          template: row.template ?? 'jakes',
          resume_text: row.resume_text,
        });
      } catch (e) {
        console.error('Unhandled pipeline failure:', e);
      }
    })()
  );

  return new Response(JSON.stringify({ ok: true }), {
    status: 202,
    headers: { 'Content-Type': 'application/json' },
  });
});
