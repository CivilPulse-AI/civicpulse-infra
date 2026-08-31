# CivicPulse AI: Implementation Master Checklist

Product plan and build order for CivicPulse AI. Check boxes as work lands. This is the platform roadmap, not a hosting guide.

## Suggested technology stack

| Area | Choice |
| --- | --- |
| Frontend (mobile and web) | Flutter, for cross-platform consistency across iOS, Android, and Web |
| Backend services | Go / Golang for the core API and notification workers (high concurrency); Python for telephony and AI parsing logic |
| Database and geospatial | PostgreSQL with PostGIS (backend mapping); Hive, Isar, or SQLite for mobile offline caching |
| AI and machine learning | LLMs for transcription, translation, and parsing; custom anomaly-detection agents |
| Telephony and voice automation | Outbound conversational voice agents (specialized SDKs or Twilio / Bland AI equivalents) |
| Location services | Geocoding APIs (e.g. Google Maps API, Mapbox) for converting addresses to coordinates |
| Monetization and billing | RevenueCat for subscription management; Stripe for payment processing |

Repos that map to this stack:

- `civicpulse-citizen-app` — Flutter mobile
- `civicpulse-institution-portal` — Flutter web
- `civicpulse-server` — Go core API
- `civicpulse-ai-service` — Python AI engine
- `civicpulse-telephony-service` — Python telephony worker
- `civicpulse-notification-service` — Go notification worker
- `civicpulse-infra` — contracts, compose, and this plan

## Features to implement (chronological order)

### Phase 1: Core infrastructure, auth, and privacy foundation

- [x] **Database and stack setup:** Initialize the PostgreSQL database with the PostGIS extension enabled. Set up the foundational Go Gin backend, the Python worker environment, and initialize two separate Flutter repositories (one for the Citizen App, one for the Institutional Web Portal).
- [ ] **No live tracking logic:** Establish strict privacy-first location handlers at the OS level. The app must only request permission to fetch a one-time GPS coordinate when the user actively presses "Submit," with no background location tracking allowed.
- [ ] **Regulatory data retention and security:** Implement database-level encryption at rest for sensitive user data. Create the API endpoints required for standard user data deletion flows to comply with GDPR/DPDP regulations.
- [ ] **Platform-wide multilingualism:** Build the local UI translation infrastructure (e.g. Flutter l10n) so the app automatically adapts its display language based on the user's native device settings.
- [ ] **Gated institutional onboarding:** Build the manual domain verification flow for B2G clients. Ensure there is no self-serve signup for institutions; admins must manually provision accounts after verifying `.gov` or official municipal email domains.
- [ ] **Citizen authentication and home zones:** Implement Phone Number and OTP (One-Time Password) login for citizens. Following a successful login, mandate a mandatory onboarding step where the user drops a static "Home Zone" pin on the map to opt-in for localized surveys.

### Phase 2: Ingestion engine and community map (citizen app)

- [ ] **Intelligent offline queueing:** Implement robust structured local storage (using Flutter packages like Hive, Isar, or SQLite). If the device has no network, the app must save the complaint payload (media paths, text, coords) locally and use a background worker to sync it to the Go API once the internet is restored.
- [ ] **Smart geotagging:** Build the logic to silently capture the exact latitude and longitude when the user opens the submission camera or starts typing. Include a manual map-pin fallback UI in case they are inside a concrete building with terrible GPS signal.
- [ ] **Multimodal submission:** Build the frontend UI and backend API routes capable of handling `multipart/form-data` uploads for voice notes (`.m4a`/`.mp3`), photos, and raw text complaints.
- [ ] **Real-time auto-translation:** Pipe incoming citizen voice notes and regional text through an LLM API. The backend must transcribe and translate everything into a standardized English JSON payload before saving it to PostgreSQL.
- [ ] **Media anonymization:** Implement background scripts (potentially using OpenCV in Python) to detect and blur faces and license plates in uploaded citizen photos before they are served to the public map API.
- [ ] **Spatial duplicate merging:** Write the PostGIS query logic (`ST_DWithin`) to detect if an incoming complaint lands within 10 meters of an active issue of the same category. If so, auto-merge them to prevent map clutter.
- [ ] **One-tap verification (upvoting):** Build the public map UI allowing citizens to view nearby issues and tap an "Upvote/Verify" button. Wire this to the backend to dynamically increase the urgency score of that specific issue.
- [ ] **Community context threads:** Enable a "reply" or "add context" feature where citizens can upload supplemental photos or text to an existing neighborhood issue created by someone else.
- [ ] **Citizen anti-abuse (shadow-banning):** Build a trust-score algorithm. If a citizen's reports are repeatedly flagged as fake by municipal workers, lower their score. Below a certain threshold, flag their account so their future submissions are saved to the database but hidden from the public map.

### Phase 3: Work orders, accountability, and resolution (B2G dashboards)

- [ ] **Smart ticket routing:** Use an LLM to categorize the translated complaint (e.g. "pipe burst" = Water Dept) and auto-route it to the appropriate institutional dashboard view.
- [ ] **Live resolution tracking:** Set up the Go Notification Worker to push real-time FCM (Firebase Cloud Messaging) notifications to citizens when their ticket status changes to "Dispatched" or "Arrived."
- [ ] **Proof of resolution:** Modify the institutional portal so that contractors or municipal workers cannot click "Resolve" without uploading a real-time, geo-tagged photo proving the fix.
- [ ] **Institutional anti-abuse (resolution verification):** Build an automated push notification sent to the original reporting citizen 24 hours after a ticket is closed, asking, "Is this actually fixed?" to audit the contractor's honesty.
- [ ] **The accountability chain (auto-escalation):** Implement strict SLA (Service Level Agreement) timers in the database. If a critical issue remains unresolved past its deadline, trigger a script to auto-generate an AI summary of the failure and email it to higher-level supervisors.

### Phase 4: Data seeding, surveys, and growth loop (telephony)

- [ ] **Institutional data seeding (CSV import):** Build a secure drag-and-drop UI on the web dashboard for CSV uploads. Connect the backend to a Geocoding API to read the text addresses in the CSV and plot the corresponding phone numbers as hidden points on the map.
- [ ] **Geofenced campaign dispatch:** Implement a map-drawing tool (polygon creation) on the web dashboard. Write the PostGIS query to extract all database phone numbers (from both CSV imports and app users' Home Zones) that fall inside the drawn shape.
- [ ] **Smart routing (waterfall delivery):** Build the cost-saving routing logic. When a survey is sent, the system must first push an in-app notification to registered users. If unanswered after 24 hours, the system falls back to adding their number to the paid AI voice calling queue.
- [ ] **Automated AI voice polling:** Integrate the chosen telephony SDK. Send the extracted phone numbers and the AI-generated script to the service to deploy multilingual conversational outbound calls.
- [ ] **Structured AI parsing:** Process the audio transcripts returned from the telephony service. Use an LLM to extract hard Yes/No data and core themes, piping this structured data into the dashboard's analytics charts.
- [ ] **Automated PII scrubbing:** Redact sensitive information (like spoken names, ID numbers, or credit cards) from the raw voice survey transcripts before saving them to the long-term database.
- [ ] **Configurable edit windows and the growth loop:** Build the SMS receipt dispatcher. The SMS link must open a read-only web page showing the transcript. To edit the response (within a 24-hour window), force the user to click a "Download App to Edit" button, driving the core acquisition loop.

### Phase 5: B2G value adds (analytics and AI alerts)

- [ ] **Institutional analytics:** Build the charting UI (using a Flutter charting library) on the dashboard to visualize average resolution times, volume of reports per ward, and SLA success rates.
- [ ] **Automated budget exports:** Create backend functions to filter complaint data by date and severity, converting the output into downloadable CSV and formatted PDF reports to help planners justify repair budgets.
- [ ] **Predictive deterioration heatmaps:** Build visual heatmap overlays on the dashboard map. Use historical complaint density to highlight areas predicted to suffer imminent infrastructure breakdowns.
- [ ] **Socioeconomic equity overlays:** Integrate third-party census or demographic APIs to overlay income or demographic data onto the map, allowing planners to ensure equitable repair response times across different neighborhoods.
- [ ] **Customizable executive digests:** Setup a Go cron job (scheduled worker) to compile weekly performance metrics into a summarized email or PDF, sending it automatically to registered city officials.
- [ ] **Anomaly detection:** Deploy a continuous background AI agent to monitor the incoming stream of complaints for sudden, statistical spikes in specific categories within a small geographic radius.
- [ ] **False-alarm cross-referencing:** Build a calendar module on the dashboard for planned maintenance (e.g. scheduled power outages). Hook the anomaly agent into this calendar to suppress alerts for known issues.
- [ ] **Emergency verification protocol:** Enable the AI to autonomously deploy a localized, automated phone survey directly to residents in an anomaly zone to verify the severity of a crisis before human intervention.

### Phase 6: Gamification, monetization, and launch

- [ ] **Citizen reputation scores:** Create a database column for "Civic Points." Award points programmatically when a user submits a report that gets officially verified and resolved, or when they upvote a valid issue.
- [ ] **Citizen rewards integration:** Build a wallet/rewards UI in the mobile app where users can see their points and exchange them for digital badges (or potential future local perks).
- [ ] **Institutional leaderboards:** Create a public-facing web route showing a ranked leaderboard of local municipal wards based on their average response times and SLA adherence.
- [ ] **Transparency badges:** Automate the awarding of visual badges to institutions on the leaderboard if they maintain high resolution rates and zero SLA violations for a set period.
- [ ] **Self-serve web billing:** Implement Stripe/RevenueCat checkout integrations on the web dashboard to allow municipalities to upgrade their software tiers via credit card.
- [ ] **Automated tier entitlements:** Write the webhook logic so that successful Stripe payments instantly update the database to unlock Premium AI features or Analytics tabs without manual sales approval.
- [ ] **Survey credit top-ups:** Create a pay-as-you-go interface allowing institutions to purchase bundles of outbound calling credits.
- [ ] **Premium SMS receipts:** Build the monetization toggle allowing institutions to pay a premium fee (e.g. 1 credit per user) to send the Growth Loop SMS receipts to non-app users post-survey.

## Potential feature suggestions (future expansion)

- **AI-assisted grant proposal generator:** A tool that analyzes local geospatial data, historical complaints, and socioeconomic overlays to automatically draft multi-page infrastructure funding grant proposals for municipalities, providing massive ROI.
- **IoT sensor integration:** An API layer designed to accept automated anomaly reports from municipal IoT devices (e.g. smart water flow meters, connected trash cans) right alongside human citizen complaints.
- **Local contractor bidding marketplace:** A module allowing municipalities to open backlogged, low-level repair tickets (like potholes) to competitive public bidding by platform-verified local contractors.
- **Accessibility and inclusive infrastructure tagging:** Dedicated reporting categories for accessibility hazards (e.g. blocked wheelchair ramps), paired with deep native mobile screen reader integrations to ensure vulnerable citizens can report issues easily.
- **Open data API for researchers:** A monetizable or publicly available read-only API offering anonymized civic datasets to universities, urban planners, and local journalists studying neighborhood degradation trends.

### AI survey generation engine (prompt-to-script)

- **Contextual document parsing:** Planners upload official PDFs or compliance rubrics. The LLM ingests them and generates survey questions that extract the exact data points required by municipal regulations.
- **Prompt-to-script:** Converts raw ideas into conversational scripts optimized for voice agents.
- **Dynamic logic branching:** The AI automatically builds smart routing based on user answers.
- **Neutrality and bias checking:** The AI scans generated questions for leading biases.
- **Duration estimation:** Calculates the exact speaking time of the script.
- **Monetization strategy:** Locked behind a Premium SaaS tier or monetized via Credit Burn.
