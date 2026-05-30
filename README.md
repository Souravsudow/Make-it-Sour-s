# 🚀 Make It Sour's

### Transform Any Resume Into a World-Class SWE Resume

**Make It Sour's** is an AI-powered resume transformation platform that converts any resume into the industry-renowned **Jake's Resume** format using advanced AI processing, stunning UI experiences, and real-time resume generation.

---

## ✨ Experience the Future of Resume Building

Imagine uploading a cluttered resume and watching it transform into a clean, recruiter-approved software engineering resume through immersive animations, intelligent parsing, and pixel-perfect formatting.

### 🎬 3D Animated User Experience

* Floating Glassmorphism Resume Cards
* Smooth 3D Transformations
* AI Processing Animations
* Dynamic Resume Morphing Effects
* Premium Motion Design Inspired by:

  * Apple
  * Arc Browser
  * Linear
  * Stripe
  * Framer

Every interaction is designed to feel futuristic, elegant, and effortless.

---

## 🌟 Key Features

### 📄 AI Resume Conversion

Convert any resume format into Jake's Resume template automatically.

### ⚡ Real-Time Processing

Track resume generation progress with live status updates.

### 🎨 Modern 3D Interface

Interactive UI with premium animations and smooth transitions.

### 📑 PDF Preview Generation

Instantly preview professionally formatted resumes.

### 🔄 Server-Sent Events

Live processing updates without refreshing the page.

### ☁️ Cloud Native Infrastructure

Built for scalability and production deployment.

---

## 🛠 Technology Stack

### Backend Architecture

* Ruby on Rails API
* Redis Queue Management
* RESTful Services
* Docker Containers

### Frontend Experience

* Remix.js
* TypeScript
* Tailwind CSS
* Vite
* Framer Motion
* Three.js Integration

### AI Layer

* Anthropic Claude
* Google Gemini
* Fireworks Llama

### Infrastructure

* Google Cloud Platform
* Cloud Build CI/CD
* Cloud Run Deployment
* Load Balancer Configuration

---

## 🏗 Architecture Overview

```text
User Upload
     │
     ▼
Frontend (Remix.js)
     │
     ▼
Rails API
     │
     ▼
AI Processing Pipeline
     │
     ▼
Resume Transformation Engine
     │
     ▼
LaTeX Generation
     │
     ▼
PDF Rendering
     │
     ▼
Live Preview Delivery
```

---

## 🎥 User Journey

### Step 01 — Upload

Users upload their resume through a beautifully animated drag-and-drop interface.

### Step 02 — AI Analysis

The system extracts and understands:

* Experience
* Education
* Skills
* Projects
* Achievements

### Step 03 — Transformation

AI restructures content into the proven Jake's Resume layout.

### Step 04 — Generation

A production-ready LaTeX resume is generated automatically.

### Step 05 — Preview

Users instantly receive a polished PDF preview.

---

## 🚀 Local Development

### Backend

```bash
cd backend
bundle install
rails server
```

### Frontend

```bash
cd frontend
npm install
npm run dev
```

---

## 🐳 Docker Deployment

```bash
docker-compose build
docker-compose up
```

---

## ☁️ Google Cloud Deployment

```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
gcloud builds submit
```

---

## 🔐 Environment Variables

### Backend

```env
ANTHROPIC_API_KEY=
FIREWORKS_API_KEY=
GEMINI_API_KEY=
REDIS_URL=
RAILS_MASTER_KEY=
SECRET_KEY_BASE=
```

### Frontend

No local environment variables required.

Production secrets are securely managed through Google Cloud Secret Manager.

---

## 📡 API Endpoints

### Upload Resume

```http
POST /api/v1/resumes
```

### Preview Resume

```http
GET /api/v1/resumes/preview
```

### Real-Time Status Updates

```http
GET /api/v1/status/events
```

---

## 🎯 Vision

Our mission is simple:

> Help developers create recruiter-ready resumes in seconds through AI, beautiful design, and world-class user experience.

No templates to edit.
No formatting headaches.
Just upload, transform, and download.

---

## 📜 License

MIT License

Built with ❤️ by Sourav Yadav
