# IRIS TestOps Hub

**IRIS TestOps Hub** is a full‑stack application for ingesting automated test results and turning them into actionable insights (top errors, flaky tests, run‑to‑run regressions).

Built for the **InterSystems Full Stack Contest**:
- ✅ Backend: **InterSystems IRIS** (ObjectScript REST + SQL)
- ✅ Full CRUD from the UI (projects)
- ✅ Data ingest via REST (runs, tests, errors)
- ✅ Analytics & dashboards in IRIS
- ✅ Embedded Python inside IRIS (fingerprinting, similarity, flaky scoring)
- ✅ Open‑source, Docker‑first

## Features
- **Projects CRUD** (create/rename/delete)
- **Secure API** (bearer session tokens)
- **Ingest token per project** (rotation supported)
- **Dashboard**: pass rate, totals
- **Recent runs** list + **Run details** page
- **Diff vs previous run**: new failures, fixed failures, new error fingerprints
- **Top errors** grouped by fingerprint
- **Similar errors** (TF‑IDF cosine similarity via Embedded Python)
- **Flaky tests**: fail rate + flaky transitions score (Embedded Python)
- **Run attachments**: upload/download logs or artifacts (stored on Docker volume)
- **Test annotations**: mark tests as `known-issue`, `flaky`, `xfail`, etc.

## Quick start
```bash
docker compose up --build
```

Open:
- Web UI: http://localhost:8080
- IRIS Management Portal: http://localhost:52773/csp/sys/UtilHome.csp (login: `_SYSTEM` / `SYS`)

Default admin is created on first boot:
- email: `admin@testops.local`
- password: `admin123`

## Demo ingestion
1) Login → create a project → copy **ingestToken**
2) Ingest sample data:

```bash
bash demo/ingest-example.sh <INGEST_TOKEN>
```

To generate history for flaky + diff:
```bash
bash demo/ingest-multi.sh <INGEST_TOKEN>
```

## API (high level)
Base URL (inside Docker): `http://localhost:52773/csp/testops/api`

- `POST /api/auth/register` / `POST /api/auth/login`
- `GET/POST /api/projects`
- `PATCH/DELETE /api/projects/:id`
- `POST /api/projects/:id/rotate-token`
- `GET /api/projects/:id/dashboard`
- `GET /api/projects/:id/runs`
- `GET /api/runs/:id`
- `GET /api/runs/:id/diff`
- `GET /api/projects/:id/errors/top`
- `GET /api/projects/:id/errors/:fingerprint/similar`
- `GET /api/projects/:id/flaky`
- `POST /api/testcases/:id/annotate`
- `POST /api/runs/:id/attachments` (JSON base64)
- `GET /api/attachments/:id/download`

## Architecture
- **IRIS**: REST endpoints in ObjectScript, persistence via IRIS SQL tables/views.
- **Embedded Python**: used for error fingerprinting, similarity ranking, and flaky scoring.
- **Web**: React SPA (Vite) served by Nginx, `/api/*` proxied to IRIS.

## Contest checklist
- Runs on **IRIS Community Edition** in containers.
- Full‑stack (web UI + CRUD + ingest + analytics).
- Open source (MIT License).
- README in English with install + demo steps.

## Demo video
Record a 2–3 minute video:
1) Login
2) Create project
3) Run demo ingest
4) Show dashboard + runs + run diff
5) Open “top errors” and “similar errors”
6) Show flaky tests
7) Upload an attachment on a run

