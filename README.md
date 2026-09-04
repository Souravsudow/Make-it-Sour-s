# 🚀 Make It Sour's

### Transform Any Resume Into a World-Class SWE Resume

**Make It Sour's** is an AI-powered resume transformation platform that converts any resume into the industry-renowned **Jake's Resume** format using AI processing, a live progress pipeline, and PDF preview generation.

---

## ✨ Key Features

* **AI Resume Conversion** — upload a PDF, DOC, DOCX, or TXT resume (or just paste raw text) and get a recruiter-ready LaTeX resume
* **Multiple Templates** — choose between **Jake's** (classic serif), **Minimal** (clean, compact), and **Modern** (sans-serif with blue accents)
* **3-Stage AI Pipeline** — Reader (extract structured data) → Polisher (strengthen bullet points) → LaTeX generator
* **Real-Time Progress** — live status updates via Server-Sent Events (SSE)
* **PDF Preview** — instantly rendered server-side with `pdflatex`
* **Overleaf Integration** — open the generated LaTeX directly in Overleaf
* **Rate Limiting** — Rack::Attack throttling per IP

---

## 🛠 Technology Stack

### Backend
* Ruby on Rails 8.0 API (no database — state lives in Redis)
* Redis for status/results/caching + Pub/Sub for real-time updates
* Sidekiq for background job processing
* Groq API (Llama models) for the AI pipeline
* Rack::Attack rate limiting · Docker

### Frontend
* Remix.js + Vite
* TypeScript · Tailwind CSS · Framer Motion
* react-pdf for PDF preview

---

## 🏗 Architecture

```text
User Upload / Paste
     │
     ▼
Frontend (Remix.js)
     │  POST /api/v1/resumes
     ▼
Rails API
     │  enqueue ResumeProcessingJob
     ▼
Sidekiq Worker
     │
     ▼
AI Pipeline (Groq)
  Reader → Polisher → LaTeX
     │
     ▼
pdflatex → PDF
     │
     ▼
SSE status updates → Live Preview
```

### How it flows

1. **Upload** — the frontend POSTs a file (or pasted text) plus a chosen `template`.
2. **Accept** — the API validates size/type, generates a `request_id`, and enqueues `ResumeProcessingJob` via Sidekiq.
3. **Process** — the job runs the 3-stage Groq pipeline and publishes status updates (Redis + Pub/Sub) at each stage.
4. **Preview** — the frontend streams status via SSE, then fetches the PDF from `/preview`, which compiles the LaTeX with `pdflatex` and caches the result in Redis.

---

## 🚀 Local Development

### Prerequisites
* Ruby 3.4.1 (see `backend/.ruby-version`)
* Node 20+
* Redis (`redis-server`)
* Groq API keys (one or more — see below)

### Backend

```bash
cd backend
bundle install

# Terminal 1 — web server
bin/rails server

# Terminal 2 — job worker (required! jobs won't run without it)
bundle exec sidekiq -C config/sidekiq.yml

# Redis must be running locally: redis-server
```

### Frontend

```bash
cd frontend
npm install
npm run dev
```

The Vite dev server proxies `/api/*` to `http://localhost:3000` automatically.

### Tests

```bash
cd backend
bundle exec rspec

cd frontend
npm run typecheck
npm run lint
```

---

## 🐳 Docker

There is no docker-compose file. The backend image runs **both** the Rails server and the Sidekiq worker via `bin/start`, so one container is enough:

```bash
docker build -t makeitjakes-backend ./backend
docker run -p 8080:8080 \
  -e REDIS_URL=redis://host.docker.internal:6379/0 \
  -e GROQ_API_KEY=your-key \
  makeitjakes-backend
```

---

## ☁️ Google Cloud Deployment

```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
gcloud builds submit
```

`cloudbuild.yaml` runs the backend test suite, builds/pushes both images, and deploys them to Cloud Run. Secrets are managed through Secret Manager.

---

## 🔐 Environment Variables

### Backend

| Variable | Description |
|---|---|
| `GROQ_API_KEY_READER`, `_2`, `_3`, `_4` | API keys for the Reader stage (rotated on 401/429) |
| `GROQ_API_KEY_POLISHER`, `_2`, `_3` | API keys for the Polisher stage |
| `GROQ_API_KEY_LATEX`, `_2`, `_3` | API keys for the LaTeX stage |
| `GROQ_API_KEY` | Fallback single key used if no stage-specific keys are set |
| `GROQ_MODEL_<STAGE>` | Optional model override per stage (e.g. `GROQ_MODEL_LATEX`) |
| `REDIS_URL` | Redis connection URL (default `redis://localhost:6379/0`) |
| `REDIS_POOL_SIZE` | Redis connection pool size (default `10`) |
| `MAX_UPLOAD_BYTES` | Max upload size in bytes (default `10485760` / 10MB) |
| `PDF_COMPILE_TIMEOUT` | pdflatex timeout in seconds (default `60`) |
| `SSE_TIMEOUT_SECONDS` | SSE stream timeout in seconds (default `180`) |
| `CORS_ORIGINS` | Allowed CORS origins (default `*`) |
| `SECRET_KEY_BASE` | Rails secret key base (production) |

### Frontend

| Variable | Description |
|---|---|
| `VITE_API_URL` / `API_URL` | Backend origin for the API (defaults to same origin, proxied in dev) |

---

## 📡 API Endpoints

### Upload / Convert a Resume

```http
POST /api/v1/resumes
Content-Type: multipart/form-data
```

Form fields:
* `file` — the resume file (PDF, DOC, DOCX, or TXT) **or**
* `content` — raw resume text (pasted input)
* `template` — `jakes` (default), `minimal`, or `modern`

Response: `202 Accepted` with `{ "request_id": "..." }`.

### Real-Time Status Updates

```http
GET /api/v1/status/events?request_id=...
```

Server-Sent Events stream with per-stage progress, ending with `completed` or `Error: ...`.

### Preview PDF

```http
GET /api/v1/resumes/preview?request_id=...
```

Returns `{ "pdf": "<base64>", "name": "<first/last JSON>" }`. LaTeX is compiled with `pdflatex` (with a timeout and no shell escape) and cached for 1 hour.

---

## 🎯 Vision

> Help developers create recruiter-ready resumes in seconds through AI, beautiful design, and world-class user experience.

No templates to edit. No formatting headaches. Just upload, transform, and download.

---

## 📜 License

MIT License