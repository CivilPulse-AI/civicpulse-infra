# civicpulse-infra

Local orchestration and shared contracts for CivicPulse AI.

This repo is the source of truth for:

- Redis (local broker)
- gRPC protobufs (`proto/`)
- `docker compose` for running the sibling services locally
- [`PLAN.md`](PLAN.md) — platform implementation checklist and roadmap

The database is not run here. Set `DATABASE_URL` (platform) and `GOADMIN_DATABASE_URL` (separate GoAdmin database on the same cluster).

TLS-verified clusters (such as CockroachDB Cloud) need a CA. Core reads `DATABASE_CA_CERT` (PEM text) or `DATABASE_CA_CERT_PATH` (file, often `~/.postgresql/root.crt`). `CREATE EXTENSION postgis` is skipped when the engine does not support it; Cockroach has built-in `geography` types.

Application code lives in the sibling repos. Generated gRPC stubs are committed inside those repos so they still build on their own. After changing a `.proto` file, regenerate with `make proto`.

## Layout

```
PLAN.md
proto/ai/v1/ai.proto           # AIEngine service
proto/ai/v1/transcribe.proto
proto/ai/v1/extract.proto
proto/ai/v1/analyze.proto
proto/ai/v1/anonymize.proto
proto/core/v1/core.proto       # CoreIngest service
proto/core/v1/survey.proto
proto/core/v1/call.proto
proto/core/v1/ack.proto
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
cp .env.example .env   # set DATABASE_URL, GOADMIN_DATABASE_URL, GOADMIN_PASSWORD, DATABASE_CA_CERT
docker compose up --build
```

Compose fails fast if `DATABASE_URL`, `GOADMIN_DATABASE_URL`, `GOADMIN_PASSWORD`, `GEMINI_API_KEY`, `OTP_SMS_ENABLED`, or `OTP_WHATSAPP_ENABLED` is unset. For Cockroach Cloud, paste the downloaded CA PEM into `DATABASE_CA_CERT` (Docker cannot see `~/.postgresql/root.crt` unless you mount it).

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

Services are configured only through environment variables (`DATABASE_URL`, `REDIS_URL`, `PORT` / `HTTP_PORT`, health hosts, and so on). They do not assume a particular cloud. Optional provider files such as [`render.yaml`](render.yaml) can sit in this repo without leaking into application code.
