# 🚀 Make It Sour's

### Transform Any Resume Into a World-Class SWE Resume

**Make It Sour's** is an AI-powered resume transformation platform that converts any resume into the industry-renowned **Jake's Resume** format using AI processing, a live progress pipeline, and LaTeX output.

---

## ✨ Key Features

* **AI Resume Conversion** — upload a PDF, DOCX, or TXT resume (or just paste raw text) and get a recruiter-ready LaTeX resume
* **Multiple Templates** — choose between **Jake's** (classic serif), **Minimal** (clean, compact), and **Modern** (sans-serif with blue accents)
* **3-Stage AI Pipeline** — Reader (extract structured data) → Polisher (strengthen bullet points) → LaTeX generator
* **Real-Time Progress** — live status updates via Supabase Realtime
* **Overleaf Integration** — open the generated LaTeX directly in Overleaf
* **Private by design** — files are parsed **in your browser**; only extracted text is stored (and rows auto-expire)

---

## 🛠 Technology Stack

### Frontend
* Remix.js + Vite · TypeScript · Tailwind CSS · Framer Motion
* pdf.js (in-browser PDF text extraction) · mammoth.js (DOCX)
* Supabase JS client (insert + Realtime subscription)

### Backend — 100% Supabase
* **Postgres** — `resumes` table with RLS (no server of our own!)
* **Database Webhook (pg_net)** — fires the Edge Function on insert
* **Edge Function `process-resume`** — 3-stage Groq pipeline (Deno/TypeScript)
* **Realtime** — pushes every row update to the browser instantly
* **Groq API** (Llama/Qwen models) for the AI pipeline

> ℹ️ The old Rails + Sidekiq + Redis backend is retired (`backend/` kept for reference).

---

## 🏗 Architecture

```text
User Upload / Paste
     │
     ▼
Browser (Remix) ── pdf.js / mammoth extract text locally
     │
     │  insert into public.resumes (Supabase JS)
     ▼
Postgres trigger (pg_net webhook)
     │  POST /functions/v1/process-resume
     ▼
Edge Function (Deno)
     │  Groq pipeline: Reader → Polisher → LaTeX
     │  UPDATE resumes SET status=..., latex=...
     ▼
Supabase Realtime ──► Browser updates live
     │
     ▼
LaTeX output → Copy / Download .tex / Open in Overleaf
```

---

## 🚀 Setup Guide

### 1. Create a Supabase project

1. Go to [supabase.com](https://supabase.com) → **New project** (free tier is fine).
2. Note your **Project URL** and keys from **Project Settings → API**:
   - `SUPABASE_URL` → `https://<project-ref>.supabase.co`
   - `SUPABASE_ANON_KEY` → the `anon` `public` key
   - `SUPABASE_SERVICE_ROLE_KEY` → the `service_role` key (secret!)

### 2. Create the database schema

Install the Supabase CLI, then from the repo root:

```bash
supabase login
supabase link --project-ref <your-project-ref>
supabase db push
```

This runs `supabase/migrations/0001_resumes.sql`, which creates:
- the `public.resumes` table
- RLS policies (anon can insert + read)
- Realtime publication for the table
- the `handle_new_resume()` trigger + pg_net webhook

Then set the two custom settings the webhook reads:

```sql
-- Run in the Supabase SQL editor:
alter system set app.settings.function_url =
  'https://<project-ref>.supabase.co';
alter system set app.settings.service_role_key =
  '<your-service-role-key>';
select pg_reload_conf();
```

> Alternative if `alter system` is blocked: use the Dashboard →
> Database → Webhooks UI to create the equivalent insert webhook,
> or store both values in Vault and adapt the trigger.

### 3. Deploy the Edge Function

```bash
supabase functions deploy process-resume
supabase secrets set GROQ_API_KEY=gsk_...   # from console.groq.com
```

Optional stage-specific keys (rotated automatically on 401/429):

```bash
supabase secrets set GROQ_API_KEY_READER=gsk_... \
  GROQ_API_KEY_POLISHER=gsk_... \
  GROQ_API_KEY_LATEX=gsk_...
```

Optional model overrides: `GROQ_MODEL_READER`, `GROQ_MODEL_POLISHER`, `GROQ_MODEL_LATEX`.

### 4. Configure + run the frontend

```bash
cd frontend
npm install

# .env (local dev)
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_ANON_KEY=<your-anon-key>

npm run dev
```

### 5. Deploy the frontend (Netlify)

Set these environment variables in Netlify → Site settings → Environment:

| Variable | Value |
|---|---|
| `SUPABASE_URL` | `https://<project-ref>.supabase.co` |
| `SUPABASE_ANON_KEY` | your anon key |

Then deploy. `netlify.toml` already builds via the Remix Netlify adapter.

---

## 🔌 How it works

1. **Extract (browser)** — `lib/resumes.ts` reads PDF via pdf.js / DOCX via mammoth / TXT directly. Nothing is uploaded except the extracted text.
2. **Insert** — a row is inserted into `public.resumes` with `resume_text` + `template`.
3. **Webhook** — `handle_new_resume()` calls the `process-resume` Edge Function via pg_net.
4. **Pipeline** — the Edge Function runs Reader → Polisher → LaTeX with Groq, updating the row's `status` (and finally `latex`) after each stage.
5. **Realtime** — the browser subscription receives every update and renders the progress pipeline live.

### Data lifecycle

Rows contain only extracted resume text + generated LaTeX (no original files), and you can add a daily cron cleanup:

```sql
select cron.schedule('cleanup-resumes', '0 3 * * *', $$select count(*) from pg_sleep(0); delete from resumes where created_at < now() - interval '1 day';$$);
```

*(Requires the `pg_cron` extension — enable it in the Dashboard.)*

---

## 🧪 Development

```bash
cd frontend
npm run typecheck
npm run lint
```

Edge Function local test:

```bash
supabase functions serve process-resume \
  --env-file ./supabase/.env.local
```

---

## 📜 License

MIT License
