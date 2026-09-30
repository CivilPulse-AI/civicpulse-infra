# CivicPulse AI

CivicPulse is a privacy-first civic platform that connects residents and municipal institutions around local infrastructure problems.

Citizens report issues with text, voice, or photos. Location is captured only when they act, never as background tracking. The core API turns multilingual input into structured tickets, routes them by department, and merges nearby duplicates. Institutions work from a gated web portal: SLA-backed work orders, geo-tagged proof of resolution, citizen confirmation, escalation ladders, and geofenced in-app voice surveys. Those surveys run inside the citizen app (Stencil, Relay, and Livewire). There is no PSTN carrier in this stack.

The product closes the loop most complaint tools leave open: report, dispatch, prove the fix, ask the citizen if it is actually fixed, and escalate when the SLA slips.

**The platform spans many repositories.** Application code, voice, AI, and notifications each live in their own repo. This one, `civicpulse-infra`, holds the shared contracts and the local orchestration. Clone the repos as siblings so relative paths in the Makefile and Compose file resolve.

## Repositories

| Repository | What it does |
| --- | --- |
| [civicpulse-citizen-app](https://github.com/CivilPulse-AI/civicpulse-citizen-app) | Flutter app for residents: phone OTP, a static Home Zone, complaints, the community map, and the in-app survey dialer. English and Hindi. |
| [civicpulse-institution-portal](https://github.com/CivilPulse-AI/civicpulse-institution-portal) | Flutter web portal for municipalities: inbox, crew, escalation ladders, survey campaigns, and analytics. No self-serve signup. |
| [civicpulse-server](https://github.com/CivilPulse-AI/civicpulse-server) | Go HTTP and gRPC core. Citizens and the portal talk to it. It owns auth, reports, campaigns, credits, and the database. |
| [civicpulse-ai-service](https://github.com/CivilPulse-AI/civicpulse-ai-service) | Python AI engine. The core calls it over gRPC for transcription, extraction, analysis, anonymization, and contact-column mapping. |
| [civicpulse-telephony-service](https://github.com/CivilPulse-AI/civicpulse-telephony-service) | Python voice bridge for Stencil, Relay, and Livewire. In-app WebSocket audio only; it does not place phone calls. |
| [civicpulse-notification-service](https://github.com/CivilPulse-AI/civicpulse-notification-service) | Go worker for push, email, and SMS. It consumes the notification Redis stream. |
| [civicpulse-infra](https://github.com/Nailsonseat/civicpulse-infra) | This repo. Protobuf contracts, Compose, and the scripts that start the stack on one machine. |

The institution portal also depends on `civicpulse-ui`, a local Flutter package of shared design tokens and widgets (`../civicpulse-ui`). It is not published as its own GitHub repository. Check it out beside the portal or the portal build will not resolve that path.

Expected checkout:

```
CivicPulse AI/
  civicpulse-infra/                  ← you are here
  civicpulse-citizen-app/
  civicpulse-institution-portal/
  civicpulse-ui/
  civicpulse-server/
  civicpulse-ai-service/
  civicpulse-telephony-service/
  civicpulse-notification-service/
```

Product detail and the build checklist live in [PRODUCT.md](PRODUCT.md) and [PLAN.md](PLAN.md).

## What this repo owns

- gRPC protobufs (`proto/`)
- `docker compose` for the sibling services
- `make local`, which runs the backends and the institution portal on this machine without Docker

The database and Redis are not run here. Set `DATABASE_URL` (platform), `GOADMIN_DATABASE_URL` (separate GoAdmin database on the same cluster), and `REDIS_URL` (Upstash Redis URL, `rediss://`).

TLS-verified clusters (such as CockroachDB Cloud) need a CA. Core reads `DATABASE_CA_CERT` (PEM text) or `DATABASE_CA_CERT_PATH` (file, often `~/.postgresql/root.crt`). `CREATE EXTENSION postgis` is skipped when the engine does not support it; Cockroach has built-in `geography` types.

Generated gRPC stubs are committed inside the service repos so each one still builds on its own. After changing a `.proto` file, regenerate with `make proto`.

## Layout

```
PRODUCT.md
PLAN.md
proto/ai/v1/ai.proto           # AIEngine service
proto/ai/v1/transcribe.proto
proto/ai/v1/extract.proto
proto/ai/v1/analyze.proto
proto/ai/v1/anonymize.proto
proto/ai/v1/columns.proto
proto/core/v1/core.proto       # CoreIngest service
proto/core/v1/survey.proto
proto/core/v1/call.proto
proto/core/v1/ack.proto
docker-compose.yml
scripts/local-up.sh
```

## Ports

| Service | HTTP | gRPC |
| --- | --- | --- |
| civicpulse-server | 8080 | 9090 |
| civicpulse-ai-service | 8001 | 50051 |
| civicpulse-telephony-service | 8002 (health and the survey socket) | — |
| civicpulse-notification-service | 8003 (health only) | — |

## Redis streams

Workers consume Redis Streams (not Pub/Sub), so jobs survive if a worker is down.

| Stream | Consumer group | Worker |
| --- | --- | --- |
| `civicpulse.jobs.surveys` | `telephony-workers` | civicpulse-telephony-service |
| `civicpulse.jobs.notifications` | `notification-workers` | civicpulse-notification-service |

Envelope (JSON in the `data` field of each stream entry):

```json
{
  "type": "deploy_survey",
  "idempotency_key": "optional-dedupe-key",
  "payload": {}
}
```

Typical `type` values: `deploy_survey`, `emergency_survey`, `notify`. Services hand these jobs to Redis. They do not call each other over HTTP for them.

## Run the stack

On this machine, without Docker:

```bash
cp .env.example .env
make local
```

Or with Compose:

```bash
cp .env.example .env   # set DATABASE_URL, GOADMIN_DATABASE_URL, GOADMIN_PASSWORD, DATABASE_CA_CERT, REDIS_URL
docker compose up --build
```

Compose fails fast if `DATABASE_URL`, `GOADMIN_DATABASE_URL`, `GOADMIN_PASSWORD`, `REDIS_URL`, `GEMINI_API_KEY`, `OTP_SMS_ENABLED`, or `OTP_WHATSAPP_ENABLED` is unset. For Cockroach Cloud, paste the downloaded CA PEM into `DATABASE_CA_CERT` (Docker cannot see `~/.postgresql/root.crt` unless you mount it).

Health / status:

```bash
curl http://localhost:8080/health
curl http://localhost:8080/ready
curl http://localhost:8080/v1/status
```

`GET /v1/status` is the payload for an “All systems operational” UI: it probes Core, the external database, Redis, AI, telephony, and notifications.

## Regenerate gRPC stubs

Requires `protoc`, `protoc-gen-go`, `protoc-gen-go-grpc`, and `python3 -m grpc_tools`. The sibling service checkouts must sit next to this folder.

```bash
make proto
```

Services are configured only through environment variables (`DATABASE_URL`, `REDIS_URL`, `PORT` / `HTTP_PORT`, health hosts, and so on). They do not assume a particular cloud. Optional provider files such as [`render.yaml`](render.yaml) can sit in this repo without leaking into application code.
