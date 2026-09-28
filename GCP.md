# CivicPulse AI — GCP resources for a hackathon demo

Region: **Mumbai (`asia-south1`)**. One `e2-medium` runs the four backend containers. The institution portal is a static Flutter web build on **Firebase Hosting** (free tier).

CockroachDB and Upstash are already the database and Redis. They are not created in GCP and are not in the total below.

Prices are public list rates, converted at **₹96.03 per USD** (rupee close, 28 Sep 2026). An Indian Cloud Billing account also pays **18% GST**. Re-check the [pricing calculator](https://cloud.google.com/products/calculator) before you create the project.

## Total bill

**About ₹4,300 per month** while the VM stays on, GST included.

| Resource | What you create | USD / month | INR / month |
| --- | --- | ---: | ---: |
| Compute Engine | 1× `e2-medium` (2 shared vCPU, 4 GB), on 24×7 | 29.86 | 2,868 |
| Persistent disk | 20 GB balanced, boot disk | 2.40 | 230 |
| Internet egress | A few GB (1 GB free, then ~$0.12/GB) | 0.50 | 48 |
| Gemini | Reports, Relay, ~15 short Livewire calls | 5.00 | 480 |
| Maps Geocoding | CSV addresses, inside the $200 / month Maps credit | 0 | 0 |
| Speech-to-Text and Text-to-Speech | Relay audio, inside the free minute and character tiers | 0 | 0 |
| Firebase Hosting | Institution portal | 0 | 0 |
| **Usage** | | **37.76** | **3,626** |
| GST 18% | Charged on the Google invoice | 6.80 | 653 |
| **Deducted** | | **44.56** | **₹4,300** |

A new billing account’s **$300 / 90-day credit** covers this for several months. The figure above is the amount after that credit is gone. Delete the VM and the disk after judging and the portal can stay on Firebase at ₹0.

Livewire is the line that moves. One extra hour of two-way audio is about **₹250–400**. Speech-to-Text above the free hour is **$0.016 / minute** (about ₹1.50 / minute).

## What runs where

```text
Judges
  │
  ├─ Citizen app (Flutter APK, not hosted)
  │
  ├─ Institution portal ── Firebase Hosting (free)
  │
  └─ e2-medium, Mumbai (Caddy on :443)
        ├─ civicpulse-server
        ├─ civicpulse-ai-service
        ├─ civicpulse-telephony-service
        └─ civicpulse-notification-service

CockroachDB Cloud     not GCP, not in the bill
Upstash Redis         not GCP, not in the bill
```

`HACKATHON_DEMO=true` seeds the judge citizen and institution, turns on one-tap login, and leaves Razorpay unused. OTP SMS and WhatsApp stay off.

| Repo | On GCP as |
| --- | --- |
| `civicpulse-server` | Container on the VM. Go API, GoAdmin at `/admin`. |
| `civicpulse-ai-service` | Container on the VM. Gemini transcribe / extract / anonymize. |
| `civicpulse-telephony-service` | Container on the VM. Stencil, Relay, Livewire WebSocket. |
| `civicpulse-notification-service` | Container on the VM. Upstash stream worker. |
| `civicpulse-institution-portal` | `flutter build web` uploaded to Firebase Hosting. |
| `civicpulse-citizen-app` | Android APK. No server. |
| `civicpulse-infra` | `docker compose` on the VM. |

## Resources to create

### 1. Compute Engine — ₹2,868 / month

- Machine: `e2-medium` (2 shared vCPU, 4 GB)
- Zone: `asia-south1-a` (or `-b` / `-c`)
- Image: Ubuntu 24.04 LTS
- Disk: 20 GB `pd-balanced`
- External IP: one regional static address, attached to this VM (free while the VM is running)
- Firewall: `tcp:443` from `0.0.0.0/0`, `tcp:22` from your IP only

4 GB is enough because Postgres and Redis are not on this machine. Caddy on the VM terminates HTTPS and routes:

- `api.<domain>` → server `:8080` (citizen app, portal, GoAdmin)
- `voice.<domain>` → telephony `:8002` (survey WebSocket)

AI, notifications, and the gRPC ports stay on the Docker network. Photos and baked Stencil audio use the R2 settings already in `.env` (outside this bill).

### 2. Firebase Hosting — ₹0

| Product | Use | Why it stays free |
| --- | --- | --- |
| Firebase Hosting | Institution portal | Free tier is 10 GB stored and 360 MB transferred per day. A Flutter web build is a few tens of MB. |
| Firebase Cloud Messaging | Optional push | The app already polls for survey rings if FCM is empty. |

Link the Firebase project to this GCP project if you want one invoice. Hosting itself stays on the free tier.

### 3. Google APIs — ₹480 / month at demo volume

Enable these on the same project. Keys live in the VM `.env`.

| API | Used by | Demo-month assumption | INR |
| --- | --- | --- | ---: |
| Gemini (Generative Language API key → `GEMINI_API_KEY`) | Reports, Relay, Livewire | ~300 Flash calls, ~15 Livewire sessions of 3 minutes | 480 |
| Cloud Speech-to-Text and Text-to-Speech | Relay turns | Needs `GOOGLE_SERVICE_ACCOUNT_JSON` (or the base64 form) plus `GOOGLE_CLOUD_PROJECT`. Demo volume is inside the free tiers. | 0 |
| Maps Geocoding (`GOOGLE_MAPS_API_KEY`) | CSV address → pin | Inside the Maps Platform **$200 / month credit**. | 0 |

The speech clients read that JSON even on a GCP VM. The VM’s own service account is not what they call.

## Not on this bill

| System | Why it is absent |
| --- | --- |
| CockroachDB | Already `DATABASE_URL` and `GOADMIN_DATABASE_URL`. |
| Upstash Redis | Already `REDIS_URL`. |
| Cloudflare R2 | Already set in `.env` for photos and baked audio. |
| Razorpay, Fast2SMS | Hackathon demo mode leaves them unused. Brevo is already set and bills Brevo, not GCP. |
| Load balancer, Cloud NAT, Secret Manager, Artifact Registry | Caddy on the VM is the HTTPS endpoint. Images are built on the machine. |

## After the event

1. Delete the VM, the boot disk, and the static IP.
2. Delete unused Gemini and Maps keys.
3. Leave Firebase Hosting. It does not bill at this size.
4. CockroachDB, Upstash, and R2 have their own consoles. Pausing those is separate from the GCP invoice.
