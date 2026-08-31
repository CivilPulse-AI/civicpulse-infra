# CivicPulse AI: Implementation Master Checklist

Product plan and build order for CivicPulse AI. Check boxes as work lands. This is the platform roadmap, not a hosting guide.

## Suggested technology stack

| Area | Choice |
| --- | --- |
| Frontend (mobile and web) | Flutter, for cross-platform consistency |
| Backend | Go for the core API and notification workers; Python for telephony and AI logic |
| Database and geospatial | PostgreSQL with PostGIS (backend); SQLite for mobile offline caching |
| AI and machine learning | LLMs for transcription, translation, and parsing; custom anomaly-detection agents |
| Telephony and voice | Outbound conversational voice agents (specialized SDKs or Twilio / Bland AI equivalents) |
| Location | Geocoding APIs (Google Maps, Mapbox, or similar) |
| Monetization and billing | RevenueCat for subscriptions; Stripe for payments |

Repos that map to this stack:

- `civicpulse-citizen-app` — Flutter mobile
- `civicpulse-institution-portal` — Flutter web
- `civicpulse-server` — Go core API
- `civicpulse-ai-service` — Python AI engine
- `civicpulse-telephony-service` — Python telephony worker
- `civicpulse-notification-service` — Go notification worker
- `civicpulse-infra` — contracts, compose, and this plan

## Features to implement (chronological)

### Phase 1: Core infrastructure, auth, and privacy foundation

- [ ] **Database and stack setup:** Initialize PostgreSQL/PostGIS, Go API, Python workers, and Flutter projects.
- [ ] **No live tracking:** Privacy-first location handlers only (static pins and manual GPS fetches).
- [ ] **Regulatory data retention:** Database-level encryption at rest and standard user data deletion flows.
- [ ] **Platform-wide multilingualism:** Localization for dynamic Flutter UI translation from device settings.
- [ ] **Gated institutional onboarding:** Manual domain verification (for example `.gov`) and admin portal provisioning. No self-serve institutional signup.
- [ ] **Citizen authentication and home zones:** Phone/OTP login; mandate a manual Home Zone static map pin during onboarding.

### Phase 2: Ingestion engine and community map (citizen app)

- [ ] **Intelligent offline queueing:** Local SQLite so reports save offline and background-sync when the network returns.
- [ ] **Smart geotagging:** Capture exact GPS on submit, with a manual map-pin fallback for bad signal.
- [ ] **Multimodal submission:** UI for voice notes, photos, and text complaints.
- [ ] **Real-time auto-translation:** Pipe citizen voice and text through LLM APIs into standardized English JSON.
- [ ] **Media anonymization:** Background detection and blur of faces and license plates in uploaded photos.
- [ ] **Spatial duplicate merging:** PostGIS auto-merge of complaints within 10 meters of an active issue.
- [ ] **One-tap verification (upvoting):** Map view so citizens can upvote/verify issues and boost urgency.
- [ ] **Community context threads:** Supplemental photos or text on existing neighborhood issues.
- [ ] **Citizen anti-abuse (shadow-banning):** Trust-score algorithm that shadow-bans users who consistently submit false reports.

### Phase 3: Work orders, accountability, and resolution (B2G dashboards)

- [ ] **Smart ticket routing:** AI categorization and auto-route to the correct department dashboard (water, roads, and so on).
- [ ] **Live resolution tracking:** Push notifications when a repair crew is dispatched and when they arrive.
- [ ] **Proof of resolution:** Contractors/workers must upload a geo-tagged photo of the fix to close a ticket.
- [ ] **Institutional anti-abuse (resolution verification):** Final nudge to the reporting citizen: “Is this actually fixed?”
- [ ] **Accountability chain (auto-escalation):** Strict SLA timers; if unresolved, auto-generate AI summaries and escalate.

### Phase 4: Data seeding, surveys, and growth loop (telephony)

- [ ] **Institutional data seeding (CSV import):** Secure dashboard CSV upload; geocode phone numbers onto the map.
- [ ] **Geofenced campaign dispatch:** Map-drawing tool so planners can extract numbers inside a polygon.
- [ ] **Smart routing (waterfall delivery):** Free in-app push surveys first; fall back to paid AI calls if unread after 24 hours.
- [ ] **Automated AI voice polling:** Telephony SDK for multilingual conversational AI calls.
- [ ] **Structured AI parsing:** Survey audio to hard yes/no data and themes for dashboard charts.
- [ ] **Automated PII scrubbing:** Redact names, cards, and similar data from voice transcripts before storage.
- [ ] **Configurable edit windows and growth loop:** Read-only web receipt that requires the app to edit an AI transcription.

### Phase 5: B2G value-adds (analytics and AI alerts)

- [ ] **Institutional analytics:** Charts for average resolution time and report volume per ward.
- [ ] **Automated budget exports:** Filtered CSV and PDF exports to help planners justify budgets.
- [ ] **Predictive deterioration heatmaps:** Historical overlays that predict future infrastructure breakdowns.
- [ ] **Socioeconomic equity overlays:** Census APIs to cross-reference resolution times with demographic maps.
- [ ] **Customizable executive digests:** Go cron worker that emails weekly performance summaries to officials.
- [ ] **Anomaly detection:** Background AI agent that flags sudden spikes in complaint types or locations.
- [ ] **False-alarm cross-referencing:** Suppress planned-outage alerts using municipal maintenance schedules.
- [ ] **Emergency verification protocol:** AI autonomously deploys localized phone surveys in anomaly zones to verify crisis severity.

### Phase 6: Gamification, monetization, and launch

- [ ] **Citizen reputation scores:** Civic points for accurate, verified reports.
- [ ] **Citizen rewards integration:** Exchange points for digital badges or local perks.
- [ ] **Institutional leaderboards:** Public page ranking wards on response times.
- [ ] **Transparency badges:** Auto-award badges to institutions that meet SLAs.
- [ ] **Self-serve web billing:** RevenueCat/Stripe for B2B card checkout on the dashboard.
- [ ] **Automated tier entitlements:** Unlock premium AI/analytics features on successful payment.
- [ ] **Survey credit top-ups:** Pay-as-you-go outbound calling credits.
- [ ] **Premium SMS receipts:** Upsell so institutions can text non-app users after a survey.

## Potential features (future expansion)

- **AI-assisted grant proposal generator:** Analyze local geospatial and socioeconomic overlays and draft multi-page infrastructure funding proposals for municipalities.
- **IoT sensor integration:** API layer for automated anomaly reports from municipal IoT (smart water meters, connected trash cans) alongside citizen complaints.
- **Local contractor bidding marketplace:** Open backlogged low-level repair tickets (for example potholes) to competitive bidding by platform-verified local contractors.
- **Accessibility and inclusive infrastructure tagging:** Categories for accessibility hazards (blocked wheelchair ramps) plus native screen-reader support so vulnerable citizens can report issues.
- **Open data API for researchers:** Monetizable or public read-only API of anonymized civic datasets for universities, planners, and journalists.

### AI survey generation engine (prompt-to-script)

- **Contextual document parsing (rubric upload):** Planners upload official PDFs, SOPs, or compliance rubrics. The LLM guarantees generated questions extract the data points required by municipal rules.
- **Prompt-to-script:** Convert raw ideas into conversational scripts optimized for the voice agent.
- **Dynamic logic branching:** Automatic smart routing in the survey.
- **Neutrality and bias checking:** Scan generated or typed questions for leading bias.
- **Duration estimation:** Exact speaking time of the generated script.
- **Monetization:** Lock behind the premium SaaS tier, or bill via credit burn.
