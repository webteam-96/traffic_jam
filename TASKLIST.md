# trafficjam.life — Project Task List

Source of truth: `Business Flow Document v1.2` (client-approved scope) +
`docs/API_REQUIREMENTS.md` + `docs/BACKEND_REQUIREMENTS.md`.

Status legend: `[x]` done · `[~]` in progress · `[ ]` not started

---

## Phase 0 — Frontend completion (Flutter, `frontend/`)

The app ships today with 100% mocked data and no networking layer. This
phase finishes the UI surface so every business-flow screen exists, before
wiring it to a real API in Phase 3a.

### 0.1 Kundli expansion (client-requested scope addition, June 2026)
- [x] Dashamsha (D10) and Shastiamsha (D60) added to the Charts tab
- [x] KP System tab (sub-lord table + live ruling planets)
- [x] Cusp Chart tab (per-house cusp degree + planets)
- [x] North Indian / South Indian chart style toggle
- [x] D60 "requires exact birth time" lock for unknown-birth-time profiles
- [x] Vargottama note on the Navamsha (D9) view
- [x] Get Kundli flow — form, mock generation, saved-Kundli list, delete
- [x] Kundli Landing screen (My Kundli / Get Kundli hub)
- [x] Share icon on every Kundli tab (mocked)
- [x] Fixed a live rendering bug in `GlassCard` (`goldTopBorder` + radius
      combo crashed on every repaint — now a clipped accent strip instead of
      a non-uniform `Border`)

### 0.2 Remaining frontend gaps — done
- [x] Onboarding: dedicated Consent/trust screen (§3 step 9) — new step 4-of-4
      `ConsentScreen`, 4 trust points + explicit checkbox gate, inserted
      between Birth Place and Calculating
- [x] Profile: Astro Identity Card (§12 step 3) — Lagna/Moon/Sun sign,
      Nakshatra+Pada, current Dasha lord as a chip row
- [x] Profile: Saved Kundlis section (§12 step 4) — reads the same
      `KundliStore` as the Kundli landing screen, tap to view, "+ NEW" to
      generate, "VIEW ALL KUNDLIS" to the full landing screen
- [x] Profile: real Privacy actions — new `PrivacyScreen` (export-data
      request, consent history list, delete-account confirmation dialog;
      export/delete are mocked confirmations since no backend exists yet)
- [x] Notifications: split filter into System vs. Team-announcement (§7
      step 4) — replaced All/Unread with All/System/Team, each row tagged
- [x] Notification preferences: added WhatsApp as a channel option (§7 step
      7) — per-category Push/Email/WhatsApp chips, shown when that category
      is enabled
- [x] Vibe Meter / Color of the Day / Astro Insights / Planet Strengths —
      client decision: **keep as-is**. Not in the v1.2 Business Flow doc,
      but not in conflict with it either; revisit only if the client objects.

### 0.3 Deferred to Phase 3a (needs a backend to mean anything)
- [ ] Wire a real HTTP client + auth/session state — every screen today is
      `StatelessWidget`/`StatefulWidget` over mock consts, there is no data
      layer at all yet. Not attempted in Phase 0 since there is nothing to
      connect to until Phase 1 exists.

---

## Phase 1 — Backend (in progress)

Stack per `docs/BACKEND_REQUIREMENTS.md`: .NET Core 8, MySQL 8, Redis,
Swiss Ephemeris (native lib), Firebase Auth, FCM, a payment gateway.
**Deviations locked in this session** (see `backend/README.md`): built as
one **modular monolith** rather than 5 separate microservices, and targets
**.NET 10** (LTS, already installed) rather than .NET 8.

### 1.1 Foundation
- [x] Repo scaffold — `backend/`, one ASP.NET Core Web API project
      (`TrafficJam.Api`), Docker Compose for local MySQL 8 + Redis,
      `/health` endpoint verified against both
- [x] MySQL schema + first migration for all 12 tables from
      `BACKEND_REQUIREMENTS.md` §Data model (`Users`, `BirthData`, `Charts`,
      `Dashas`, `DailySignals`, `PanchangCache`, `Questions`, `Messages`,
      `Subscriptions`, `NotificationPrefs`, `Devices`, `RemedyContent`) —
      applied and verified against the real dev database. `Charts` already
      includes D10/D60/KP/Cusp columns to match the Kundli expansion.
- [x] AES-256 encryption at rest for `birth_data` (DPDP Act 2023
      requirement) — AES-256-**GCM** via an EF Core value converter, so
      application code works with plain values and MySQL only ever stores
      ciphertext. Proven with an integration test that reads the raw MySQL
      column directly, not just an app-level round-trip.
- [ ] Redis cache layer wired in for real (chart: permanent · dasha:
      per-month · signal/vibe/color/panchang: per-user-per-day) — the
      connection is live and health-checked, but no module writes through
      it yet; that happens as each module is built
- [ ] NGINX API gateway config: TLS 1.3, rate limiting (stricter on
      `/auth/*` and `/consult/questions`) — deployment-time concern, not
      needed for local dev

### 1.2 Auth Service — done (needs a real Firebase project to be usable end-to-end)
- [x] Firebase phone-OTP integration — server-side verification built
      (`IFirebaseTokenVerifier` + Firebase Admin SDK); fails with a clear
      503 rather than a crash until a real service account is configured
- [x] `POST /auth/session` — verifies the Firebase ID token, upserts the
      user, issues a short-lived app JWT + rotating refresh token (opaque,
      stored only as a hash, revoked-on-use). Also handles the edge case of
      the same phone number returning under a new Firebase UID (reinstall/
      re-verification) by re-linking instead of crashing on the unique
      index — a real bug the test suite caught.
- [x] `POST /auth/refresh` — added beyond the doc's literal endpoint list;
      structurally necessary for the documented short-lived-JWT +
      refresh-token model to actually work
- [x] `POST /auth/otp/resend` — in-memory cooldown ledger (30s), no DB table
      needed since it's purely ephemeral
- [x] `GET /me`, `GET /config` (app-version gate / feature flags)

### 1.3 Astro Engine — ON HOLD (licensing decision, not technical)
Swiss Ephemeris is dual-licensed: free under AGPL-3.0 (which legally requires
publishing this entire backend's source, since running it as a network
service triggers AGPL's obligations), or a paid Professional License from
Astrodienst (no public pricing — contact them) to stay closed-source. Parked
here pending that business decision — see `backend/README.md` §Astro Engine.
Everything below this section is blocked until it's resolved.
- [ ] Swiss Ephemeris integration (P/Invoke or sidecar service)
- [ ] Birth chart generation: Lagna, Moon/Sun signs, 9 planets with house
      placement, Nakshatra, and now D9/D10/D60 divisional charts + KP
      sub-lords + cusp chart (frontend already expects all of these)
- [ ] Vimshottari Dasha computation (Maha/Antar/Pratyantar), monthly refresh
- [ ] Daily transit (Gochar) batch job — nightly, per active user
- [ ] Panchang computation — cached per `city:date` (Tithi, Nakshatra, Yoga,
      Karana, Rahu Kaal, Yamaganda Kaal, Gulika Kaal, Abhijit Muhurat,
      sunrise/sunset/moonrise/moonset)
- [ ] Traffic Signal scoring — weighted composite (Moon transit 30% +
      Panchang 25% + Dasha 25% + major transits 20%) → Green/Yellow/Red +
      plain-language driver explanations
- [ ] `POST /onboarding/complete`, `GET /chart?varga=`, `GET /chart/strengths`,
      `GET /dasha`, `GET /dasha/timeline`, `GET /panchang/today`,
      `GET /signal/today`, `GET /muhurat/today`, `GET /vibe/today`,
      `GET /color/today`, `GET /insights`, `GET /dashboard/home`

### 1.4 User Service — done except the parts that need the Astro Engine
- [x] `GET/PUT /me/birth-data` — PUT saves birth data (encrypted, same as
      onboarding) and clears any onboarding draft. Regeneration itself is a
      `TODO(astro-engine)` stub — can't invalidate/regenerate a chart that
      can't be computed yet
- [x] `GET/PATCH /onboarding/draft` — resumable onboarding, partial-update
      semantics (only provided fields overwrite), same encryption as real
      birth data since it holds the same sensitive fields mid-entry
- [x] Google Places proxy: `GET /places/autocomplete`, `GET /places/geocode`
      — real Google Places + Time Zone API calls built (`GooglePlacesClient`);
      fails with a clean 503 until a real API key is configured
- [x] `GET/PUT /me/notification-preferences` — includes per-category
      Push/Email/WhatsApp channel selection to match the frontend's Phase 0.2 work
- [x] `POST /me/devices` — FCM token registration (dedupes by token)

### 1.5 Consultation Service — done except context-attach (needs Astro Engine) and Book Appointment
- [x] `GET /consult/plans`, `POST /consult/questions`, `GET /consult/questions`,
      `GET/POST /consult/questions/{id}/messages`
- [ ] Context auto-attach (chart + Dasha + transits + Panchang) on question
      submit — `TODO(astro-engine)` stub (empty object) until the engine exists
- [ ] WebSocket or FCM data-push for realtime Ask Jay replies — needs the
      same Firebase project as Auth
- [ ] Book Appointment lead capture endpoint (new — not yet in
      `API_REQUIREMENTS.md`, needed for the Business Flow §9 form)
- [x] `GET /subscription`, `GET /subscription/plans`,
      `POST /subscription/checkout`, `POST /subscription/verify`,
      `POST /payments/checkout` — `IPaymentGateway` interface built; fails
      with a clean 503 until a real Razorpay/Stripe account is configured
- [ ] `/webhooks/payments` reconciliation — needs a real gateway to receive webhooks from

### 1.6 Notification Service — inbox done, delivery infra not started
- [x] `GET /notifications`, `POST /notifications/{id}/read`,
      `POST /notifications/read-all` (added beyond the doc — the "mark all
      read" button would otherwise mean one request per notification)
- [ ] FCM push infrastructure — needs the same Firebase project as Auth
- [ ] Scheduled jobs: Morning Briefing queue (05:00 IST), Rahu Kaal warnings
      (rolling, 15 min before), planetary-event alerts, Dasha reminders,
      remedy reminders — most of these need the Astro Engine to know what to send
- [ ] Admin-authored banner/announcement delivery (respecting quiet hours +
      channel prefs)

### 1.7 Compliance
- [ ] Data export + delete-account endpoints (DPDP/GDPR right to erasure)
- [ ] Audit logging, no PII in logs
- [ ] Pen-test before launch

---

## Phase 2 — Admin Panel (does not exist yet — full build)

Separate product for the Kaizen/astrologer team. Not specified in detail
anywhere in this repo yet (Business Flow §14 is a business-level summary
only) — needs its own design pass before implementation starts.

- [ ] Choose stack (likely a web app — React/Next or a .NET-hosted admin UI
      to share auth with the backend)
- [ ] Banner management — create/schedule/target (all users, region, tier),
      start/end time, draft/publish (§14.1)
- [ ] Announcement composer — title/body/image, deep-link target, audience,
      send-now or scheduled (§14.2)
- [ ] Leads queue — appointment requests with chart context attached,
      status tracking (Contacted/Scheduled/Completed/Cancelled) (§14.3)
- [ ] Ask Jay response queue — question + attached chart context, reply
      composer with optional voice-note upload, SLA timer display (§14.4)
- [ ] Cosmic Foundations CMS — edit the 6 pages' text/illustrations/subtitle,
      review + publish flow (§14.5)
- [ ] Admin auth + role management (astrologer vs. panel astrologer vs. admin)

---

## Phase 3a — App Integration (Flutter app ↔ backend only)

- [x] Add an HTTP client + typed API layer to the Flutter app — `ApiClient`
      (auto Bearer header, one silent-refresh-and-retry on 401) +
      `AuthService` (ValueNotifier session state, same lightweight pattern
      as `KundliStore`), `flutter_secure_storage` for tokens
- [x] Auth flow wired end-to-end, verified live in a running browser session:
      Splash checks a stored session against `/me` and routes to
      Login/Welcome(onboarding)/Shell accordingly; Login → OTP → session
      persists across a full page reload; logout clears it. Real Firebase
      isn't configured yet, so this runs through the backend's dev-mode
      login (`POST /auth/dev-login`, fixed OTP "123456") — see "Dummy login"
      below. **Swap for the real Firebase Auth SDK once a Firebase project
      exists** — this bullet was originally "Firebase Auth SDK wired into
      Login/OTP screens"; the SDK integration itself is still a task, this
      is the interim path that makes the rest of the app usable now.
- [x] Found and fixed a real bug along the way: `Program.cs` had no CORS
      policy, so `flutter run -d chrome` (a different origin than the API)
      was silently blocked by the browser. Added a dev-only permissive CORS
      policy — doesn't affect native iOS/Android builds (CORS is
      browser-only) or production (gated to `IsDevelopment()`).
- [~] Replace every screen's mock consts with real API calls + loading/error
      states — in progress, done incrementally. So far: **Profile's Birth
      Artifacts card** (real GET /me/birth-data, loading/empty/populated
      states) and **Edit Birth Data** (full real form — date/time pickers,
      a curated city list standing in for the unconfigured Places API,
      GET-on-load + PUT-on-save, pops `true` so Profile reloads) and
      **Notification Prefs** (real GET/PUT /me/notification-preferences,
      including the per-category Push/Email/WhatsApp channels). All three
      verified live against the real backend — including catching and
      fixing a real bug (see below). Astro Identity Card stays mocked
      (needs the Astro Engine); Subscription/Saved-Kundlis untouched this
      pass. Most of the daily-data screens (Home, Panchang, Kundli, Dasha,
      Signal, etc.) still can't be wired for real regardless, since they
      need the Astro Engine (on hold)
- [ ] FCM client registration + push notification handling — needs a real
      Firebase project (same one Auth needs)
- [ ] Payment SDK integration (Razorpay/Stripe client) for Ask Jay + Subscription
- [ ] End-to-end test of the full onboarding → chart generation → daily
      Traffic Signal loop against the real backend — blocked on the Astro
      Engine

### Dummy login (interim, until a real Firebase project exists)
`POST /auth/dev-login` accepts **any phone number** with the fixed OTP
**`123456`**. Gated behind `Auth:DevModeEnabled` (true only in
`appsettings.Development.json`) — `Program.cs` refuses to even start if
that's ever true outside the Development environment, so it can never ship.
The OTP screen shows an on-screen hint ("Dev mode — no real SMS is sent. Use
code 123456.") so this doesn't need to be explained out-of-band to testers.

## Phase 3b — Admin Panel Integration (Admin Panel ↔ backend)

None of this exists yet — each Phase 2 admin feature needs its own backend
endpoints, and several read back into the app itself (a banner the admin
publishes has to actually show on Home). Split out here so it isn't silently
assumed to happen "for free" as part of Phase 2's UI build-out.

- [ ] Admin auth + role management (astrologer / panel astrologer / admin) —
      almost certainly a *different* auth scheme than user-facing Firebase
      phone-OTP (email/password or SSO), and its own JWT/session handling
- [ ] Banner endpoints: admin CRUD (create/schedule/target/draft/publish) +
      a public `GET /banners/active`-style read the Flutter Home screen
      consumes (§14.1) — two-sided, not admin-only
- [ ] Announcement endpoints: admin CRUD + send-now/scheduled trigger that
      hooks into the Notification Service's push infra (§14.2)
- [ ] Leads queue endpoints: admin CRUD + status transitions
      (Contacted/Scheduled/Completed/Cancelled) over the Book Appointment
      leads captured by 1.5 (§14.3)
- [ ] Ask Jay response queue: admin-side view over the existing
      `Questions`/`Messages` tables (already built — an astrologer's reply
      is just a `Message` with `Sender = Astrologer`, which the schema
      already supports) + optional voice-note upload (needs object storage) (§14.4)
- [ ] Cosmic Foundations CMS endpoints: admin CRUD for the 6 pages' content
      (currently hardcoded in the Flutter app) + review/publish workflow,
      and the read-side the app would eventually fetch from instead of
      its hardcoded copy (§14.5)
- [ ] End-to-end test of a full admin workflow (publish a banner → appears
      in the app; answer an Ask Jay question → user sees the reply) against
      the real backend

## Phase 4 — Launch prep

- [ ] Security review (see `docs/BACKEND_REQUIREMENTS.md` §Security checklist)
- [ ] Load-test the nightly batch jobs (transit/signal/panchang precompute)
- [ ] App Store / Play Store listing + build signing
- [ ] Staged rollout plan

---

## Currently working on

**Phase 0 is complete.** Everything buildable without a backend is done —
see git history for the full file list. `flutter analyze`/`flutter test`
clean, every screen spot-checked live. Only item 0.3 (wiring real data)
remains, gated on Phase 1.

**Phase 1 (backend) — Foundation, Auth, User, Notification, and Consultation
are done.** Everything that doesn't need the Astro Engine is built and
tested: `backend/` is a .NET 10 modular monolith (`TrafficJam.Api`), Docker
Compose for local MySQL 8 + Redis, the full schema applied via EF Core
migrations, AES-256-GCM birth-data encryption (proven against the raw MySQL
column, not just an app-level round-trip), and working endpoints for Auth
(session/refresh/otp-resend/me/config), User (birth-data/onboarding-draft/
notification-prefs/devices/places-proxy), Notifications (inbox), and
Consultation (Ask Jay questions+messages, plans, Subscription). 36/36 tests
passing — all integration-level against the real dev database, not mocks.
See `backend/README.md` for the full endpoint table and setup.

**1.3 Astro Engine is ON HOLD** — not a technical blocker, a licensing one.
Swiss Ephemeris is dual-licensed AGPL-3.0 (would require open-sourcing this
entire backend) or a paid Astrodienst Professional License (no public
pricing). Parked pending that business decision — see `backend/README.md`
§Astro Engine for the full explanation. Blocks: chart generation, Panchang,
Dasha, Traffic Signal, Vibe Meter, Color of the Day, Astro Insights, and the
context-attach step of Ask Jay.

**Also blocked on external credentials, not code** — each fails cleanly
(503) rather than crashing until configured:
- A **Firebase project** — for `/auth/session` to actually verify tokens, and for FCM push
- A **Google Places API key** — for the birth-place autocomplete/geocode proxy
- A **payment gateway account** (Razorpay/Stripe) — for subscription/Ask-Jay checkout

**Phase 3a (App Integration) is started.** The HTTP client + session layer
exist (`ApiClient`, `AuthService`) and the full Auth flow is wired and
verified live end-to-end: Login → dummy-OTP → session persists across a
reload → correct Login/Welcome/Shell routing → logout. Backend's
`/auth/dev-login` (any phone, fixed OTP `123456`) stands in for real
Firebase until that project exists — see Phase 3a's "Dummy login" note.
Also found and fixed a real bug: the backend had no CORS policy, so the
Flutter web build was silently blocked calling it; fixed with a dev-only
policy that doesn't touch native builds or production.

**Profile is wired to real birth data and notification prefs.** New
`UserApi` service (typed wrapper over /me/birth-data and
/me/notification-preferences, wire format verified directly against the
running backend rather than assumed from .NET's serializer defaults).
Profile's Birth Artifacts card, a fully rebuilt Edit Birth Data form
(date/time pickers + a curated city list — Google Places isn't configured
yet, so this reuses the same standing-in-with-known-coordinates approach
`GetKundliScreen` already used), and Notification Prefs are all real now —
verified live: seeded birth data via curl, logged into the app with that
phone number, watched the Edit Birth Data form correctly prefill with the
exact seeded values (name, DOB, 24h→12h TOB conversion, city selection).
`flutter analyze`/`flutter test` and all 39 backend tests still clean.

**Next up, in no particular required order:**
- Keep wiring the app to real data — Ask Jay and Subscription endpoints
  already exist and don't need the Astro Engine; the Astro Identity Card
  and every daily-data screen (Home/Panchang/Kundli/Dasha/Signal) still
  can't be, pending the engine
- Resolve the Astro Engine licensing question and resume Phase 1.3
- Get real credentials for Firebase/Places/payments so what's built can be
  fully exercised (real phone OTP, real place search, real checkout)
- Start Phase 2 (Admin Panel) or Phase 3b (Admin Panel Integration) groundwork
