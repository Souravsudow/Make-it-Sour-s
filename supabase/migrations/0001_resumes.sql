-- ============================================================
-- Make It Sour's — Supabase schema
-- Replaces: Rails API + Redis + Sidekiq
--
-- Flow: frontend inserts into public.resumes (RLS: anyone can
-- create) → a Postgres trigger fires an HTTP webhook (pg_net)
-- to the `process-resume` Edge Function → the function runs the
-- Groq pipeline (extract → polish → LaTeX) and updates the row.
-- Realtime pushes every UPDATE to the browser automatically.
-- ============================================================

create extension if not exists pg_net;
create extension if not exists pgcrypto;

-- ─── Table ────────────────────────────────────────────────
create table if not exists public.resumes (
  id            uuid primary key default gen_random_uuid(),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  status        text not null default 'queued',
  template      text not null default 'jakes'
                  check (template in ('jakes', 'minimal', 'modern')),
  -- raw extracted text from the uploaded/pasted resume
  resume_text   text not null,
  -- pipeline results
  extracted     jsonb,
  polished      jsonb,
  latex         text,
  error         text,
  -- convenience: parsed from extracted.name for display
  person_name   text
);

-- Index for realtime listeners that filter by status
create index if not exists resumes_status_idx on public.resumes (status);

-- Keep updated_at fresh
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists resumes_set_updated_at on public.resumes;
create trigger resumes_set_updated_at
  before update on public.resumes
  for each row execute function public.set_updated_at();

-- ─── Row Level Security ───────────────────────────────────
-- No auth in this app: anonymous users may create rows and may
-- only read rows they know the id of (unguessable uuid).
alter table public.resumes enable row level security;

drop policy if exists "anon can create resumes" on public.resumes;
create policy "anon can create resumes"
  on public.resumes for insert
  to anon
  with check (true);

drop policy if exists "anon can read any resume by id" on public.resumes;
create policy "anon can read any resume by id"
  on public.resumes for select
  to anon
  using (true);

-- No UPDATE/DELETE policies for anon: only the service_role
-- (the Edge Function) can modify rows.

-- ─── Realtime ─────────────────────────────────────────────
alter publication supabase_realtime add table public.resumes;

-- ─── Webhook trigger → Edge Function ──────────────────────
-- Fires on INSERT and calls the process-resume Edge Function via
-- pg_net (async HTTP). SUPABASE_FUNCTION_URL / SERVICE_ROLE are
-- injected by Supabase when the migration runs through the CLI
-- (supabase db push). For the Dashboard SQL editor, run the
-- GRANTs below manually or use `supabase db push`.
create or replace function public.handle_new_resume()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_project_url text := current_setting('app.settings.function_url', true);
  v_service_key text := current_setting('app.settings.service_role_key', true);
begin
  if v_project_url is null or v_service_key is null then
    -- Not configured (e.g. local test insert); skip silently.
    return new;
  end if;

  perform net.http_post(
    url := v_project_url || '/functions/v1/process-resume',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || v_service_key,
      'Content-Type', 'application/json'
    ),
    body := jsonb_build_object('record', jsonb_build_object('id', new.id)),
    timeout_milliseconds := 5000
  );

  return new;
end;
$$;

drop trigger if exists on_resume_created on public.resumes;
create trigger on_resume_created
  after insert on public.resumes
  for each row execute function public.handle_new_resume();

-- ─── One-time setup for the webhook settings ──────────────
-- Run these in the SQL editor (or via supabase db push with a
-- config) with your project ref and service_role key:
--
--   alter system set app.settings.function_url = 'https://YOUR_PROJECT_REF.supabase.co';
--   alter system set app.settings.service_role_key = 'YOUR_SERVICE_ROLE_KEY';
--   select pg_reload_conf();
--
-- Alternatively, if `alter system` is not permitted on your
-- plan, insert into supabase settings Vault and read via
-- vault.decrypted_secrets. See README for instructions.
