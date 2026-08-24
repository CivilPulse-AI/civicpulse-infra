# civicpulse-infra

Local orchestration and shared contracts for CivicPulse AI.

This repo is the source of truth for:

- Redis (local broker)
- gRPC protobufs (`proto/`)
- `docker compose` that builds the four sibling microservices
- [`render.yaml`](render.yaml) Blueprint for deploying those services on Render

Postgres is **not** run here (locally or on Render). Point `DATABASE_URL` at your external PostGIS instance.

Postgres is **not** run here. Point `DATABASE_URL` at your external PostGIS instance.

Application code lives in the sibling repos. Generated gRPC stubs are committed inside those repos so they still build on their own. After changing a `.proto` file, regenerate with `make proto`.

## Layout

```
proto/ai/v1/ai.proto       # AIEngine — implemented by civicpulse-ai-service
proto/core/v1/core.proto   # CoreIngest — implemented by civicpulse-server
docker-compose.yml
```

Sibling services (expected next to this folder):

- `../civicpulse-server`
- `../civicpulse-ai-service`
- `../civicpulse-telephony-service`
- `../civicpulse-notification-service`

## Ports

| Service | HTTP | gRPC |
| --- | --- | --- |
| Redis | 6379 | — |
| civicpulse-server | 8080 | 9090 |
| civicpulse-ai-service | 8001 | 50051 |
| civicpulse-telephony-service | 8002 (health only) | — |
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

Typical `type` values: `deploy_survey`, `emergency_survey`, `notify`. Microservices must not call each other for these jobs — they only `XADD` to Redis.

## Run the stack

```bash
cp .env.example .env   # set DATABASE_URL to your PostGIS URI
docker compose up --build
```

The Core API must be able to reach that database (PostGIS extension required). Compose fails fast if `DATABASE_URL` is unset.

Health / status:

```bash
curl http://localhost:8080/health
curl http://localhost:8080/ready
curl http://localhost:8080/v1/status
```

`GET /v1/status` is the payload for an “All systems operational” UI: it probes Core, the external database, Redis, AI, telephony, and notifications.

## Regenerate gRPC stubs

Requires `protoc`, `protoc-gen-go`, `protoc-gen-go-grpc`, and `python3 -m grpc_tools`.

```bash
make proto
```

## Render

[`render.yaml`](render.yaml) deploys on Render **free** instance types:

| Render resource | Type | Repo |
| --- | --- | --- |
| `civicpulse-api` | web | `CivilPulse-AI/civicpulse-server` |
| `civicpulse-ai` | web | `CivilPulse-AI/civicpulse-ai-service` |
| `civicpulse-telephony` | web | `CivilPulse-AI/civicpulse-telephony-service` |
| `civicpulse-notifications` | web | `CivilPulse-AI/civicpulse-notification-service` |
| `civicpulse-redis` | Key Value (free) | — |

Private services, background workers, and Redis persistence are not available on the free plan. AI, telephony, and notifications are therefore free web services (they get public `onrender.com` URLs). Redis `persistenceMode` is `off`, so queued jobs are lost on restart.

Free web services spin down after idle time; the first request after that can be slow, and `GET /v1/status` may show workers as down until they wake.

1. Connect GitHub repos `civicpulse-infra`, `civicpulse-server`, `civicpulse-ai-service`, `civicpulse-telephony-service`, and `civicpulse-notification-service` to Render.
2. Create a Blueprint from this repo and `render.yaml`.
3. When prompted, paste your PostGIS `DATABASE_URL`.
4. After the first deploy, `GET https://<civicpulse-api>/v1/status` should report all six components.

Region is `singapore`. Change it in `render.yaml` before the first sync if you want another region (it cannot be changed later).
