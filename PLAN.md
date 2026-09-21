# CivicPulse AI: Implementation Master Checklist

Product plan and build order for CivicPulse AI. Check boxes as work lands. This is the platform roadmap, not a hosting guide.

## Suggested technology stack

| Area | Choice |
| --- | --- |
| Frontend (mobile and web) | Flutter, for cross-platform consistency across iOS, Android, and Web |
| Backend services | Go / Golang for the core API and notification workers (high concurrency); Python for in-app voice surveys, WebSocket bridging, and AI parsing |
| Database and geospatial | PostgreSQL with PostGIS (backend mapping); Hive, Isar, or SQLite for mobile offline caching |
| AI and machine learning | LLMs for transcription, translation, and parsing; custom anomaly-detection agents |
| Voice surveys | In-app mock dialer (no PSTN). **Stencil** (cached IVR), **Relay** (`gemini-3.8-flash` generateContent + STT/TTS), **Livewire** (`gemini-3.8-live` with blocking or non-blocking tools). Cellular and WhatsApp calling are deferred. |
| Location services | Geocoding APIs (e.g. Google Maps API, Mapbox) for converting addresses to coordinates |
| Monetization and billing | Institution credit ledger for survey modes; Razorpay (UPI) for INR top-ups; RevenueCat / Stripe optional for SaaS tiers |

Repos that map to this stack:

- `civicpulse-citizen-app` — Flutter mobile
- `civicpulse-institution-portal` — Flutter web
- `civicpulse-server` — Go core API
- `civicpulse-ai-service` — Python AI engine
- `civicpulse-telephony-service` — Python in-app voice survey worker (WebSocket / mock-dialer sessions; not a PSTN carrier)
- `civicpulse-notification-service` — Go notification worker
- `civicpulse-infra` — contracts, compose, and this plan

## Features to implement (chronological order)

### Phase 1: Core infrastructure, auth, and privacy foundation

- [x] **Database and stack setup:** Initialize the PostgreSQL database with the PostGIS extension enabled. Set up the foundational Go Gin backend, the Python worker environment, and initialize two separate Flutter repositories (one for the Citizen App, one for the Institutional Web Portal).
- [x] **No live tracking logic:** Establish strict privacy-first location handlers at the OS level. The app must only request permission to fetch a one-time GPS coordinate when the user actively presses "Submit," with no background location tracking allowed.
- [x] **Regulatory data retention and security:** Implement database-level encryption at rest for sensitive user data. Create the API endpoints required for standard user data deletion flows to comply with GDPR/DPDP regulations.
- [x] **Platform-wide multilingualism:** Build the local UI translation infrastructure (e.g. Flutter l10n) so the app automatically adapts its display language based on the user's native device settings.
- [x] **Gated institutional onboarding:** Build the manual domain verification flow for B2G clients. Ensure there is no self-serve signup for institutions; admins must manually provision accounts after verifying official municipal email domains. Operator UI is GoAdmin at `/admin` (separate framework DB + platform DB); `/v1/admin/*` remains for scripting.
- [x] **Citizen authentication and home zones:** Implement Phone Number and OTP (One-Time Password) login for citizens. Following a successful login, mandate a mandatory onboarding step where the user drops a static "Home Zone" pin on the map to opt-in for localized surveys.

### Phase 2: Ingestion engine and community map (citizen app)

- [x] **Intelligent offline queueing:** Implement robust structured local storage (using Flutter packages like Hive, Isar, or SQLite). If the device has no network, the app must save the complaint payload (media paths, text, coords) locally and use a background worker to sync it to the Go API once the internet is restored.
- [x] **Smart geotagging:** Build the logic to silently capture the exact latitude and longitude when the user opens the submission camera or starts typing. Include a manual map-pin fallback UI in case they are inside a concrete building with terrible GPS signal.
- [x] **Multimodal submission:** Build the frontend UI and backend API routes capable of handling `multipart/form-data` uploads for voice notes (`.m4a`/`.mp3`), photos, and raw text complaints.
- [x] **Real-time auto-translation:** Pipe incoming citizen voice notes and regional text through an LLM API. The backend must transcribe and translate everything into a standardized English JSON payload before saving it to PostgreSQL.
- [x] **Media anonymization:** Implement background scripts (potentially using OpenCV in Python) to detect and blur faces and license plates in uploaded citizen photos before they are served to the public map API.
- [x] **Spatial duplicate merging:** Write the PostGIS query logic (`ST_DWithin`) to detect if an incoming complaint lands within 10 meters of an active issue of the same category. If so, auto-merge them to prevent map clutter.
- [x] **One-tap verification (upvoting):** Build the public map UI allowing citizens to view nearby issues and tap an "Upvote/Verify" button. Wire this to the backend to dynamically increase the urgency score of that specific issue.
- [x] **Community context threads:** Enable a "reply" or "add context" feature where citizens can upload supplemental photos or text to an existing neighborhood issue created by someone else.
- [x] **Citizen anti-abuse (shadow-banning):** Build a trust-score algorithm. If a citizen's reports are repeatedly flagged as fake by municipal workers, lower their score. Below a certain threshold, flag their account so their future submissions are saved to the database but hidden from the public map.

### Phase 3: Work orders, accountability, and resolution (B2G dashboards)

- [x] **Smart ticket routing:** Use an LLM to categorize the translated complaint (e.g. "pipe burst" = Water Dept) and auto-route it to the appropriate institutional dashboard view.
- [x] **Live resolution tracking:** Set up the Go Notification Worker to push real-time FCM (Firebase Cloud Messaging) notifications to citizens when their ticket status changes to "Dispatched" or "Arrived."
- [x] **Proof of resolution:** Modify the institutional portal so that contractors or municipal workers cannot click "Resolve" without uploading a real-time, geo-tagged photo proving the fix.
- [x] **Institutional anti-abuse (resolution verification):** Build an automated push notification sent to the original reporting citizen 24 hours after a ticket is closed, asking, "Is this actually fixed?" to audit the contractor's honesty.
- [x] **The accountability chain (auto-escalation):** Implement strict SLA (Service Level Agreement) timers in the database. If a critical issue remains unresolved past its deadline, trigger a script to auto-generate an AI summary of the failure and email it to higher-level supervisors.

### Phase 4: Data seeding, surveys, and in-app mock dialer

Voice surveys run inside the citizen app. There is no PSTN, WhatsApp Calling, or carrier KYC in this phase. CSV-imported numbers still plot on the map; live mock-dialer sessions only reach signed-in app users until a later outbound channel exists.

Campaign modes (product names — use these in the dashboard, not "IVR / Basic / Advanced"):

| Mode | What it is | Model |
| --- | --- | --- |
| **Stencil** | Pre-cached keypad tree. Pay once to bake TTS; runtime is static audio + DTMF. | TTS at finalize only |
| **Relay** | Turn-based survey. Agent speaks → beep (mic hot) → citizen talks → **Press 1 to submit**. | `gemini-3.8-flash` as a normal generateContent LLM (text in/out). Separate STT + TTS. Not the Live API. |
| **Livewire** | Bidirectional live conversation with barge-in. | `gemini-3.8-live` Live API. Tools: async (`NON_BLOCKING`, default) and sync (`BLOCKING`). |

- [x] **Institutional data seeding (CSV import):** Build a secure drag-and-drop UI on the web dashboard for CSV uploads. Connect the backend to a Geocoding API to read the text addresses in the CSV and plot the corresponding phone numbers as hidden points on the map.
- [x] **Geofenced campaign dispatch:** Implement a map-drawing tool (polygon creation) on the web dashboard. Write the PostGIS query to extract all database phone numbers (from both CSV imports and app users' Home Zones) that fall inside the drawn shape.
- [x] **Institution credit ledger:** Give each institution a centralized platform-credit wallet used for any AI or call feature. Deduct by mode (see table below). Show remaining credits and estimated campaign cost before dispatch. If a Relay or Livewire session runs the wallet to zero mid-call, intercept the WebSocket, play a cached "This survey has concluded. Thank you for your time" clip, and close the session so provider APIs cannot overrun.
- [x] **Campaign mode picker:** On the dashboard, let the institution choose **Stencil**, **Relay**, or **Livewire** for each campaign. Route the citizen's survey WebSocket to that execution engine.
- [x] **Citizen mock dialer:** Native Flutter incoming-call UI (accept / decline, DTMF keypad). Capture microphone audio, enforce `echoCancellation: true` (AEC — required so Livewire does not barge-in on its own speaker leak), resample to 16-bit PCM 16 kHz little-endian, and stream to the backend over WebRTC or WebSocket. DTMF is a lightweight JSON event (`{"event": "dtmf", "key": "1"}`), not in-band audio.
- [x] **In-app survey ring:** When a geofenced campaign launches, push FCM to matching app users so the mock dialer rings. No 24-hour fallback to a paid cellular queue in this phase.
- [x] **Stencil (cached IVR):** Visual drag-and-drop call tree (menu, announce, collect digits, branches). Language + voice are chosen on the canvas. **Preview** a short free TTS sample of the selected voice before spend. On **Finalize**, show a confirmation popup: review the tree, the chosen language, and the credit cost; submitting deducts credits and bakes audio. Hash each node's text (dirty-node check) so a later typo on Node 3 regenerates and charges **only** that node. Cache `.mp3`/`.wav` against the tree in object storage. Nodes with `{dynamic_variables}` cannot be pre-baked — the UI must warn that those nodes burn credits **per call** because TTS runs at runtime. Execution: stream cached Node 1 → keypad JSON → state machine → next file. Static nodes cost nothing at runtime.
- [x] **Relay (`gemini-3.8-flash`, turn-based):** Strict turn-taking. The agent asks (or answers a detour), then a **beep earcon** means the mic is hot. Pair the beep with UI: mic icon gray → pulsing red, plus a live waveform. Citizen speaks an answer, a clarifying question, or a navigation request ("go back to the water supply question"). They **press 1 to submit** (DTMF ends the turn — no VAD required, so we never cut them off mid-sentence). Optional later: VAD endpointing (~1.5–2 s silence) as a hands-free extra, not the primary closer. Pipeline: audio blob → STT → one **normal** `gemini-3.8-flash` generateContent call (text in, text out; **no** Live API, **no** native audio generation) → TTS → stream audio → beep. Flash supports function calling, structured outputs, and thinking (`low` / `medium` / `high`; `minimal` errors). Keep thinking at `low` for latency. Deduct credits per turn (STT + Flash tokens + TTS).
- [x] **Relay tools (user never sees IDs):** Expose `record_answer(question_id, value)`, `get_current_question()`, and `jump_to_question(question_id)`. The citizen never hears or types an ID. Flash maps phrases like "the water supply question" onto the right `question_id` from conversation history, emits the tool JSON, the backend updates survey state, returns the tool result, then Flash speaks ("Sure, back to water supply. How would you rate it now?") and the beep plays. If the user asked a side question instead of answering, Flash answers it, re-asks the current survey item, then beeps. If they answered normally, Flash calls `record_answer` and advances. Structured outputs on Flash can optionally wrap the spoken reply plus tool args in one schema; still persist answers from tools, not from free text.
- [x] **Livewire (`gemini-3.8-live`):** Backend proxies 16 kHz PCM from the dialer into the Live API WebSocket and returns 24 kHz PCM. Audio is the response modality; enable output transcription if we need a text log. **Do not** send `thinking_level` / `thinking_config` (unsupported on this model). **Do not** expect structured JSON replies — Livewire has no structured outputs; survey data exists only if tools fire. Function calling supports **both** modes: default is async `behavior: NON_BLOCKING` (model keeps talking while the tool runs); set `behavior: BLOCKING` on survey-progression tools (`record_answer`, `jump_to_question`, `submit_survey_step`) so Q2 cannot start before the DB write for Q1. Use `NON_BLOCKING` plus scheduling (`SILENT`, `WHEN_IDLE`, `INTERRUPTED`) only for lookups that may run in the background. `proactive_audio` cannot be disabled — the system prompt must order the agent to wait through thinking silence, not fill it with "are you still there?". Lock the campaign language in session setup (e.g. "Conduct this entire survey in Hindi") so code-switching does not drift. Do not send video frames unless needed (default turn coverage includes video and burns tokens). Keep tool schemas short; bidirectional audio is ~25–30 tokens/s. Deduct credits continuously from session duration / audio tokens.
- [x] **Structured survey ingest:** Persist DTMF (Stencil) and tool-call answers (`question_id`, value) into Postgres and expose them on dashboard analytics. Livewire has no structured outputs — never parse Live audio bytes as the source of truth. Relay may use Flash structured outputs as a secondary schema, but still treat tools as canonical. For open-ended Relay/Livewire turns, run a post-session LLM pass for Yes/No and themes.
- [x] **Automated PII scrubbing:** Redact spoken names, ID numbers, and similar sensitive tokens from raw survey transcripts before long-term storage.
- [x] **In-app transcript review:** After a session, show the citizen a read-only transcript in the app with a 24-hour edit window. SMS receipts and "download the app to edit" remain deferred until an outbound SMS/PSTN channel exists.

Survey credit burn (communicate this on the institution dashboard):

| Mode | Deduct when | Predictability | Best for |
| --- | --- | --- | --- |
| **Stencil** | Finalize tree (TTS character count, dirty nodes only). `{variable}` nodes also burn per runtime call. | Exact for static trees; 1,000 plays of a baked node cost the same as 1 | Mass 1–5 ratings and keypad trees |
| **Relay** | Each submitted turn (STT + `gemini-3.8-flash` + TTS) | Variable; detours and chatty respondents cost more | Structured surveys that need clarifying questions or "go back" |
| **Livewire** | Continuous WebSocket duration (audio tokens, ~25–30/s) | High variance | Qualitative / open-ended interviews |

### Phase 5: B2G value adds (analytics and AI alerts)

- [ ] **Institutional analytics:** Build the charting UI (using a Flutter charting library) on the dashboard to visualize average resolution times, volume of reports per ward, and SLA success rates.
- [ ] **Automated budget exports:** Create backend functions to filter complaint data by date and severity, converting the output into downloadable CSV and formatted PDF reports to help planners justify repair budgets.
- [ ] **Predictive deterioration heatmaps:** Build visual heatmap overlays on the dashboard map. Use historical complaint density to highlight areas predicted to suffer imminent infrastructure breakdowns.
- [ ] **Socioeconomic equity overlays:** Integrate third-party census or demographic APIs to overlay income or demographic data onto the map, allowing planners to ensure equitable repair response times across different neighborhoods.
- [ ] **Customizable executive digests:** Setup a Go cron job (scheduled worker) to compile weekly performance metrics into a summarized email or PDF, sending it automatically to registered city officials.
- [ ] **Anomaly detection:** Deploy a continuous background AI agent to monitor the incoming stream of complaints for sudden, statistical spikes in specific categories within a small geographic radius.
- [ ] **False-alarm cross-referencing:** Build a calendar module on the dashboard for planned maintenance (e.g. scheduled power outages). Hook the anomaly agent into this calendar to suppress alerts for known issues.
- [ ] **Emergency verification protocol:** Enable the AI to autonomously deploy a localized in-app mock-dialer survey (Stencil, Relay, or Livewire) to residents in an anomaly zone to verify the severity of a crisis before human intervention. Same credit ledger and mode picker as Phase 4.

### Phase 6: Gamification, monetization, and launch

- [ ] **Citizen reputation scores:** Create a database column for "Civic Points." Award points programmatically when a user submits a report that gets officially verified and resolved, or when they upvote a valid issue.
- [ ] **Citizen rewards integration:** Build a wallet/rewards UI in the mobile app where users can see their points and exchange them for digital badges (or potential future local perks).
- [ ] **Institutional leaderboards:** Create a public-facing web route showing a ranked leaderboard of local municipal wards based on their average response times and SLA adherence.
- [ ] **Transparency badges:** Automate the awarding of visual badges to institutions on the leaderboard if they maintain high resolution rates and zero SLA violations for a set period.
- [ ] **Self-serve web billing:** Implement checkout on the web dashboard so municipalities can upgrade software tiers. Prefer Razorpay (UPI / INR) for Indian institutions; Stripe/RevenueCat remain optional for card billing.
- [ ] **Automated tier entitlements:** Write the webhook logic so that successful payments instantly update the database to unlock Premium AI features or Analytics tabs without manual sales approval.
- [ ] **Survey credit top-ups:** Pay-as-you-go UPI (Razorpay) wallet top-ups that refill the Phase 4 credit ledger (Stencil finalize, Relay per-turn, Livewire per-second).
- [ ] **Premium SMS receipts (deferred channel):** Monetization toggle to send growth-loop SMS receipts to non-app users after a survey. Requires an outbound SMS provider; not part of the in-app mock dialer.

## Potential feature suggestions (future expansion)

- **AI-assisted grant proposal generator:** A tool that analyzes local geospatial data, historical complaints, and socioeconomic overlays to automatically draft multi-page infrastructure funding grant proposals for municipalities, providing massive ROI.
- **IoT sensor integration:** An API layer designed to accept automated anomaly reports from municipal IoT devices (e.g. smart water flow meters, connected trash cans) right alongside human citizen complaints.
- **Local contractor bidding marketplace:** A module allowing municipalities to open backlogged, low-level repair tickets (like potholes) to competitive public bidding by platform-verified local contractors.
- **Accessibility and inclusive infrastructure tagging:** Dedicated reporting categories for accessibility hazards (e.g. blocked wheelchair ramps), paired with deep native mobile screen reader integrations to ensure vulnerable citizens can report issues easily.
- **Open data API for researchers:** A monetizable or publicly available read-only API offering anonymized civic datasets to universities, urban planners, and local journalists studying neighborhood degradation trends.
- **Outbound PSTN / WhatsApp calling:** Later optional waterfall for CSV contacts who never installed the app. Indian prepaid (UPI) carriers such as Exotel for cellular and MSG91/Gupshup for WhatsApp; not required to ship Phase 4.

### AI survey generation engine (prompt-to-script)

- **Contextual document parsing:** Planners upload official PDFs or compliance rubrics. The LLM ingests them and generates survey questions that extract the exact data points required by municipal regulations.
- **Prompt-to-script:** Converts raw ideas into Stencil node copy or Relay/Livewire conversational scripts.
- **Dynamic logic branching:** The AI automatically builds smart routing based on user answers (Stencil trees and Relay/Livewire tool-call flows).
- **Neutrality and bias checking:** The AI scans generated questions for leading biases.
- **Duration estimation:** Calculates the exact speaking time of the script.
- **Monetization strategy:** Locked behind a Premium SaaS tier or monetized via Credit Burn.
