# CivicPulse AI

CivicPulse is a privacy-first civic platform that connects residents and municipal institutions around local infrastructure problems.

A resident reports a broken road, a water cut, or a missed waste pickup with text, a photo, or a voice note. The city sees a structured ticket, sends someone to fix it, and has to prove the work with a photo from the spot. The original reporter is asked whether it is actually fixed. If the deadline passes, the issue climbs an escalation ladder. Cities can also call the people who live in an affected area and ask a short set of questions, inside the same app.

Location is taken only when the person acts. The app does not follow anyone in the background. A resident sets a home area once, and that is what makes them eligible for a local survey.

**The platform spans several repositories.** Each one is a piece of the same product. This repository, `civicpulse-infra`, is the shared home for how those pieces fit together.

## Repositories

| Repository | What it is |
| --- | --- |
| [civicpulse-citizen-app](https://github.com/CivilPulse-AI/civicpulse-citizen-app) | The mobile app for residents. Reports, the neighbourhood map, and incoming survey calls. |
| [civicpulse-institution-portal](https://github.com/CivilPulse-AI/civicpulse-institution-portal) | The web portal for a municipality. Inbox, crews, deadlines, and survey campaigns. |
| [civicpulse-server](https://github.com/CivilPulse-AI/civicpulse-server) | The core of the platform. Accounts, tickets, campaigns, and the record of what happened. |
| [civicpulse-ai-service](https://github.com/CivilPulse-AI/civicpulse-ai-service) | Reads a complaint and turns it into a clear ticket: language, category, and which department should own it. |
| [civicpulse-telephony-service](https://github.com/CivilPulse-AI/civicpulse-telephony-service) | Runs the voice surveys: a keypad script, a turn-by-turn conversation, or a live conversation. |
| [civicpulse-notification-service](https://github.com/CivilPulse-AI/civicpulse-notification-service) | Tells people when something changes: a crew is on the way, a fix needs confirmation, or a deadline was missed. |
| [civicpulse-infra](https://github.com/Nailsonseat/civicpulse-infra) | This repository. The map of the platform and the shared agreements between the other repos. |

The institution portal also uses `civicpulse-ui`, a shared look and feel that lives beside these folders. It is not a separate published repository.

## For residents

Someone signs in with their phone. They pin the area they live in, then file what they see. A photo, a written note, or a spoken description all become the same kind of ticket. Nearby people can confirm an issue that is already on the map, so the city sees one problem with many witnesses instead of a pile of duplicates.

When the city marks the work done, the person who reported it is asked if the fix is real. They can also receive a short call about services in their area, answer in the app, and review what was said.

The app speaks English and Hindi, following the language of the phone.

## For institutions

A city does not sign itself up. An official account is opened after the municipal domain is checked. Staff then work from one portal.

The inbox shows what is open, what is late, and who it is assigned to. A dispatcher sends a crew. The crew can close a ticket only with a photo taken at the site. If the deadline passes, the issue moves up a ladder the city configured, from the desk to the next person responsible.

The same portal is where a city runs a survey. They draw the area, choose who lives inside it, and pick how the call should feel:

- **Stencil** is a fixed script. The resident answers with the keypad.
- **Relay** is a spoken conversation, one question at a time.
- **Livewire** is a continuous conversation the resident can interrupt.

Results come back as answers and themes, tied to the area that was drawn.

## Google Cloud on the platform

CivicPulse is built on Google’s tools, from the apps people touch to the intelligence behind a ticket and a call.

**Flutter** is the interface. The resident app and the municipal portal are both Flutter, so the two sides of the product share one design language.

**Gemini** reads what people submit. A voice note or a message in a local language is transcribed, translated, and filed under the right department, with a sense of how serious it is. Gemini also runs the two conversational survey styles: Relay asks one question at a time, and Livewire stays in a live back-and-forth. After a set of calls, it groups what residents said into themes.

**Cloud Speech-to-Text** and **Cloud Text-to-Speech** are the ears and the voice of a survey. The city line speaks in the chosen voice, and a spoken answer is turned back into text.

**Google Maps** places things in the city. A PIN code, a street address, or a list of contacts becomes a point on the map, and a campaign only reaches people whose home area falls inside the shape the city drew.

**Firebase** carries the municipal portal to the web, and is how residents are told that a crew was dispatched, that a fix needs their confirmation, or that a deadline has moved up the ladder.
