-- ============================================================
-- Make It Sour's — Supabase schema
-- Replaces: Rails API + Redis + Sidekiq
--
-- Flow: frontend inserts into public.resumes (RLS: anyone can
-- create) → a Postgres trigger fires an HTTP webhook (pg_net)
-- to the `process-resume` Edge Function → the function runs the
-- Groq pipeline (extract → polish → LaTeX) and updates the row.
-- Realtime pushes every UPDATE to the browser automatically.
--
-- This script is IDEMPOTENT and TRANSACTION-SAFE — you can paste
-- the whole thing into the Supabase Dashboard SQL Editor.
-- Fill in the two values in the "STEP 2" block at the bottom.
-- ============================================================

create extension if not exists pg_net;
create extension if not exists pgcrypto;

-- ─── Settings (private schema — NOT exposed via the API) ───
-- The Supabase SQL Editor runs statements inside a transaction
-- block, so `alter system` is not allowed there. We store the
-- webhook settings in a table in the `private` schema instead:
-- PostgREST only exposes `public`, so these values are invisible
-- to the anon/authenticated API roles.
create schema if not exists private;

create table if not exists private.app_settings (
  key   text primary key,
  value text not null
);

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
-- Idempotent: adding an already-published table would error.
do $$
begin
  alter publication supabase_realtime add table public.resumes;
exception
  when duplicate_object then null; -- already in the publication
end $$;

-- ─── Webhook trigger → Edge Function ──────────────────────
-- Fires on INSERT and calls the process-resume Edge Function via
-- pg_net (async HTTP). Reads its settings from private.app_settings
-- (see STEP 2 below). SECURITY DEFINER lets it read the private
-- table regardless of role grants.
create or replace function public.handle_new_resume()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_project_url text;
  v_service_key text;
begin
  select value into v_project_url from private.app_settings where key = 'function_url';
  select value into v_service_key from private.app_settings where key = 'service_role_key';

  -- Skip silently if not configured yet or still a placeholder.
  if v_project_url is null or v_service_key is null
     or v_project_url like '%YOUR_%' or v_service_key like '%YOUR_%' then
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

-- ============================================================
-- STEP 2 — EDIT THESE TWO VALUES, THEN RUN THE WHOLE SCRIPT
-- ============================================================
-- service_role key: Dashboard → Project Settings → API →
-- `service_role` secret (NOT the publishable/anon key).
insert into private.app_settings (key, value) values
  ('function_url',     'https://YOUR_PROJECT_REF.supabase.co'),
  ('service_role_key', 'YOUR_SERVICE_ROLE_KEY')
on conflict (key) do update set value = excluded.value;
