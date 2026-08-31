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

### 1.3 Astro Engine — done, built on Astronomy Engine (not Swiss Ephemeris)
Switched away from Swiss Ephemeris on 2026-08-31 rather than wait on its
AGPL-vs-paid-license decision — now built on [Astronomy Engine](https://github.com/cosinekitty/astronomy)
(MIT license, pure C#, ~1 arcminute accuracy). See `backend/README.md`
§Astro Engine for the full writeup, including why that accuracy gap doesn't
matter at astrology scale, and how the ayanamsa/house-cusp pieces Swiss
Ephemeris would have given for free are implemented instead.
- [x] Astronomy Engine integration (NuGet package, pure C#, no P/Invoke)
- [x] Birth chart generation: Lagna (via a numerically-searched horizon
      crossing, not Swiss Ephemeris's `swe_houses`), Moon/Sun signs, all 9
      planets (Surya...Ketu, Rahu/Ketu via the standard mean-node formula)
      with house placement + retrograde flags, Nakshatra+Pada, Navamsha (D9),
      and the Moon chart (Chandra Kundli) — wired into `PUT /me/birth-data`,
      so saving birth data now computes and stores a real chart. Verified
      both with unit tests (including validating the Ascendant against a
      real geometric fact — it must equal the Sun's longitude at sunrise —
      rather than a hand-derived "expected" number) and live against the dev
      database (a mid-May-1990 Mumbai birth landed the Sun at 0°33' sidereal
      Taurus, matching hand-calculated expectations).
- [x] D10 (Dashamsha) and D60 (Shashtiamsha) divisional charts — both
      formulas cross-checked against an independent open-source
      implementation. D10 follows the classical odd/even starting-sign rule
      exactly (verified against worked examples). **D60 is the one formula
      in this codebase without full classical consensus** — some sources
      describe an odd/even reversal that some software applies to the sign
      mapping and some don't; this uses the simpler no-reversal convention,
      documented as a chosen convention (see `VedicMath.ShastiamshaSignIndex`
      and `backend/README.md` §Astro Engine) — **worth a professional
      astrologer's review**, same as the Traffic Signal score's point
      values. D60 also honors the frontend's existing "requires exact birth
      time" rule (§0.1) — returns null for unknown-birth-time profiles,
      since a 0°30' D60 slice is too narrow for an approximate time to mean
      anything; D10's much wider 3° slices don't have this problem. Verified
      with unit tests and live against the dev database for both a
      known-time profile (matched by hand-calculation) and an unknown-time
      one (D10 populated, D60 correctly empty)
- [x] KP sub-lords + cusp chart — the last piece of the Astro Engine; it's
      now fully built. The sign/star/sub/sub-sub lordship chain is pure
      degree arithmetic (Sub Lord reuses the exact same proportional-
      subdivision math as Dasha's Antardasha, now shared via
      `VimshottariConstants.cs`). The genuinely new piece is **Placidus
      house cusps** — KP's own house system, distinct from the whole-sign
      houses used everywhere else, with no closed-form solution (solved
      numerically, same technique as `AscendantCalculator`). This is also
      the one part of the whole Astro Engine build where tests caught two
      real bugs before they shipped (a house-index mapping error and a
      fraction-convention mismatch that swapped cusps 11/12) rather than
      just confirming correctness — see `backend/README.md` §Astro Engine.
      Verified with unit tests and live against the dev database, including
      cusp 1 matching, to 10 decimal places, the Ascendant this same test
      birth data produced when the Astro Engine was first verified live,
      several features ago in this session
- [x] Vimshottari Dasha computation (Maha/Antar/Pratyantar) — a fixed formula
      on the chart's Moon Nakshatra position, not a new engine call; wired
      into `PUT /me/birth-data` alongside chart regeneration. Verified with
      invariant-based unit tests (gapless, sums exactly to the parent period,
      one hand-verified exact case) and live against the dev database.
      Monthly refresh for users who don't re-save birth data still needs the
      scheduled-job infrastructure (not built yet, see 1.1's Redis note)
- [x] Daily transits (Gochar) — today's graha positions placed into whole-
      sign houses counted from the user's own natal Lagna and Moon (a
      `HouseFromSign` helper both this and the birth chart now share).
      Exposed as `GET /transits/today` (not named in API_REQUIREMENTS.md —
      transits there are a building block for `/signal/today`/`/vibe/today`/
      `/insights`/Ask Jay's context-attach, none built yet — added the same
      way other structurally-necessary undocumented endpoints were, e.g.
      `POST /auth/refresh`). First real use of Redis in this backend,
      cached per `user:date` per BACKEND_REQUIREMENTS.md's caching table —
      a real cache-fill-on-first-request, not the nightly batch job, which
      is still a not-yet-built follow-up. Verified with unit tests and live
      against the dev database, including confirming Rahu/Ketu's currently-
      transiting Aquarius/Leo axis and Saturn's Pisces transit match real
      current astrology (2025-2027), not just internal self-consistency
- [x] Panchang computation — cached per `city:date` (Tithi, Nakshatra, Yoga,
      Karana, Rahu Kaal, Yamaganda Kaal, Gulika Kaal, Abhijit Muhurat,
      sunrise/sunset/moonrise/moonset). Rahu Kaal/Yamaganda/Gulika's weekday
      lookup table cross-checked against an independent open-source
      implementation rather than trusted from memory. Exposed as
      `GET /panchang/today`, cache-fills `PanchangCache` on first request per
      city+date (the nightly ~03:00 IST precompute batch job is a separate,
      not-yet-built follow-up for pre-warming it). Verified with unit tests
      and live against the dev database, including confirming two users in
      the same city correctly share one cached row
- [x] Traffic Signal scoring — weighted composite (Moon transit 30% +
      Panchang 25% + Dasha 25% + major transits 20%) → Green/Yellow/Red +
      plain-language driver explanations. Unlike everything else in this
      section, the weights are documented but *how each factor becomes a
      0-100 number* isn't — implemented using real sourced classical rules
      for the categories (Chandra Bala, Nanda/Bhadra/Jaya/Rikta/Purna Tithi
      cycle, the 9 inauspicious Nitya Yogas, Naisargika Maitri planetary
      friendship, Guru/Shani Gochar house tables) with this implementation's
      own documented point values within each — see `backend/README.md`
      §Astro Engine for the full explanation of what's sourced vs. designed.
      Exposed as `GET /signal/today`. Verified with unit tests (including
      one that hand-derives the exact expected weighted score) and live
      against the dev database, cross-checked against the actual
      Panchang/Dasha/transit numbers those endpoints independently returned
- [x] `GET /panchang/today` — done, see above
- [x] `GET /signal/today` — done, see above
- [ ] `POST /onboarding/complete`, `GET /chart?varga=`, `GET /chart/strengths`,
      `GET /dasha`, `GET /dasha/timeline`,
      `GET /muhurat/today`, `GET /vibe/today`,
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
      fixing a real bug (see below). **Ask Jay** (new `ConsultApi` service —
      SEND QUESTION posts to `/consult/questions` and opens a real chat
      thread by ID; My Questions lists `/consult/questions` with live
      relative timestamps; chat thread does real GET/POST
      `/consult/questions/{id}/messages`) — verified live end-to-end in a
      running browser session, including sending a question and a follow-up
      message. **Subscription** (new `SubscriptionApi` service — real
      `/subscription/plans` + `/subscription`, CURRENT-plan badge, checkout
      surfaces a friendly "payments coming soon" message on the expected 503
      `PAYMENTS_NOT_CONFIGURED`) — verified live in the browser: correct
      real prices/features per plan, CURRENT badge correctly lands on Free
      even with Saga+ Monthly pre-selected as the popular default, and the
      "Payments are coming soon" toast fires correctly on checkout.
      **Notifications inbox** (new `NotificationApi` service — real
      `GET /notifications`, `POST /notifications/{id}/read`,
      `POST /notifications/read-all`; icon/tint is a presentation-layer
      lookup keyed on the backend's free-form `type` string since the
      backend doesn't send display metadata, with a generic-bell fallback
      for unrecognized types) — verified live: seeded rows directly in the
      dev database (no notification-generating jobs exist yet, so a real
      user's inbox is empty today), confirmed correct rendering, tap-to-mark-
      read, mark-all-read, and the All/System/Team filter, then round-tripped
      the read state back through a direct API call to confirm it actually
      persisted server-side, not just optimistically in the UI. Astro
      Identity Card stays mocked (needs the Astro Engine); Saved-Kundlis
      untouched this pass.
- [x] **Astro Engine screens wired** — the Astro Engine is done (see 1.3), so
      this is no longer blocked. New `PanchangApi`/`SignalApi`/`ChartApi`
      services; **Panchang tab** (real `GET /panchang/today` — Rahu Kaal
      countdown now derived from the real window instead of a hardcoded
      "always active" mock, phase dots driven by the real Tithi's position in
      its Paksha, dropped the four pillar cards' invented flavor-text since
      the backend has no equivalent). **Home's "Today's Panchang" preview**
      (same endpoint, self-contained fetch). **Traffic Signal screen** (real
      `GET /signal/today` — dial/band color driven by the real green/yellow/
      red band, weighted breakdown bars from the real per-factor scores,
      replaced the invented do/avoid checklist with the backend's real
      per-factor `driver` explanations, since there's no do/avoid list in the
      API). **Kundli screen's five tabs** (real `GET /chart` + `GET /dasha`,
      "My Kundli" only — a generated family/friend profile has no backend
      yet, see `KundliProfile`, so that path keeps its mock unchanged):
      Planet (dropped the per-planet Nakshatra column and fabricated
      explainer text — the backend only gives Moon's Nakshatra and no
      interpretive copy — explainer sheet now shows real placement facts
      instead); Dasha (real current Maha/Antar + a real elapsed-fraction
      meter, dropped invented "what this period brings" copy); Charts (D1
      renders in the real North/South diamond painter using real per-planet
      houses; D9/D10/D60 render as a real sign+degree table instead of the
      diamond, since the backend only computes each planet's varga *sign*,
      not a varga-Lagna house position — reproducing the diamond honestly
      would need that math reimplemented client-side, which risks drifting
      from the server's verified/tested version; the Vargottama callout is
      now a real D1-vs-D9 sign comparison instead of a hardcoded "Jupiter and
      Venus" claim); KP System (real cuspal sub-lord table; dropped the
      "Ruling Planets · Right Now" chips — that's a live query-time
      computation the backend doesn't expose, only natal KP); Cusp Chart
      (real cusp degrees + real per-cusp planet list). All four screens
      verified live end-to-end in a running browser session (dev-login →
      save real birth data → confirmed real, correctly-computed values
      render, including a genuine Vargottama detection and a real elapsed-
      Dasha percentage).
      **Found and fixed while verifying:** the Traffic Signal screen was
      still using the pre-Astro-Engine mock's static green "GO AHEAD" dial
      unconditionally — now colors/labels itself from the real `band` field.
- [x] **All four gaps found in the pass above are now fixed (2026-08-31):**
      - **Onboarding now actually saves birth data.** New `OnboardingData`
        static scratchpad (same lightweight pattern as `AuthService.state`/
        `KundliStore`) threads name/DOB/time/place across the 4 pushed
        screens; `identity_screen.dart` got a real `showDatePicker` (was a
        hardcoded const + "Date picker coming soon" toast); `birth_place_screen.dart`
        now uses a new shared `kCuratedCities` list (lat/lng/timezone
        attached, deduplicated out of `edit_birth_data_screen.dart`'s copy)
        instead of name-only mock suggestions; `calculating_screen.dart`
        now calls `UserApi.saveBirthData` in parallel with its cosmetic
        checklist animation and only navigates to the shell once the real
        save succeeds, with a retry screen if it fails.
      - **`my_chart_screen.dart` (MY CHART tab) reconciled with
        `kundli_screen.dart`.** Rewired to `GET /chart` + `GET /dasha` (same
        endpoints, same data) instead of its own separate mock: the Rashi
        chart uses a real per-house North-Indian diamond (extracted the
        painter into a shared `widgets/chart_painters.dart` so both screens
        draw from one implementation — this also fixed a real bug in the
        extraction: two+ planets conjunct with the Ascendant used to
        overwrite each other instead of accumulating), the Vimshottari
        Dasha card shows the real current Maha/Antar with a real elapsed-
        time progress bar and real prev/current/next Antar timeline, the
        Graha Sphuta table is real Lagna+9-planet positions, and the
        fabricated "Weekly Insight" quote card (no backend equivalent) was
        replaced with a real "Current Antardasha" summary linking to the
        Dasha timeline. `dasha_timeline_screen.dart` (the full vertical
        Mahadasha rail) was wired the same way — real `maha`/`antar` from
        `/dasha`, phase (done/active/upcoming) and progress derived from
        real dates instead of nine hardcoded mock periods.
      - **Ask Jay's context-attach is built.** `POST /consult/questions`
        now joins the user's stored chart summary (Sun/Moon sign, Nakshatra,
        Ascendant) + current Maha/Antar Dasha lords + today's Panchang
        (live) + today's major-planet transits (live) into `ContextJson`
        before creating the question — exactly the "CRUD + context join"
        `BACKEND_REQUIREMENTS.md` specifies, previously a `TODO` storing
        `"{}"`. Falls back to `"{}"` (not fabricated data) when the user
        hasn't saved birth data yet, so asking a question never blocks on
        it. Two new regression tests cover both paths.
      - **Found and fixed a related, more serious bug while wiring Dasha screens
        to real data:** `GET /dasha`'s `current` flag on each period was a
        snapshot frozen at whatever moment birth data was last saved, never
        refreshed — the "monthly scheduled job" the code comments called
        out as not-yet-built. A user who saved birth data months ago would
        see a permanently stale "current" Antardasha (Pratyantar periods run
        just weeks) on every screen this pass just wired to it. Fixed by
        having `GET /dasha` recompute `current` live from each period's own
        stored start/end on every read, which is strictly more correct than
        a cron job would have been — correctness no longer depends on a
        scheduled job existing or firing on time. One new regression test
        simulates a stale stored flag and confirms the response self-corrects.
      - Backend: 200/200 tests passing (3 new). Frontend: `flutter analyze`
        clean. **Not yet re-verified live in a running browser** — browser
        automation tooling was unreliable this session (the dev server
        answered `curl` fine throughout; Chrome itself reported
        `ERR_CONNECTION_REFUSED` and a tool-targeting error on repeated
        attempts, an environment/extension issue, not a code issue) — worth
        a live pass through onboarding → Home/Panchang/Signal/Kundli next
        time a browser session is available.
- [ ] FCM client registration + push notification handling — needs a real
      Firebase project (same one Auth needs)
- [ ] Payment SDK integration (Razorpay/Stripe client) for Ask Jay + Subscription
- [ ] End-to-end test of the full onboarding → chart generation → daily
      Traffic Signal loop against the real backend — now unblocked (onboarding
      saves real data and every screen downstream is wired); just needs a
      live browser pass once the tooling issue above clears

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
Consultation (Ask Jay questions+messages, plans, Subscription). 191/191 tests
passing — a mix of integration tests against the real dev database and unit
tests for the Astro math, not mocks. Also fixed two real bugs found this
session: the test suite's per-run database isolation was silently broken
(every `dotnet test` run was hitting the real dev database instead of its
own schema — see `backend/README.md` §Tests), and a full end-to-end pass
found that editing birth data left `GET /signal/today` and `/transits/today`
silently serving a stale cache computed from the *old* birth data — found by
editing a test profile to a completely different person and watching both
endpoints keep returning byte-for-byte identical output, no error — now
fixed, see `backend/README.md` §Astro Engine for the root cause and fix.
See `backend/README.md` for the full endpoint table and setup.

**1.3 Astro Engine is done**, built on Astronomy Engine (MIT license)
instead of Swiss Ephemeris — see `backend/README.md` §Astro Engine and
TASKLIST §1.3 above for the full explanation and what shipped. Birth chart
generation (Lagna, all 9 planets with houses/retrograde, Nakshatra, Navamsha,
Moon chart, D10, D60 — see §1.3 above for the flagged D60 convention
question), Vimshottari Dasha (Maha/Antar/Pratyantar), Panchang
(Tithi/Nakshatra/Yoga/Karana/Rahu Kaal/Yamaganda/Gulika/Abhijit/sunrise-
sunset-moonrise-moonset, `GET /panchang/today`), daily transits (Gochar,
`GET /transits/today`, first real use of Redis in this backend), the
Traffic Signal score (`GET /signal/today`, a synthesis of the other three —
see §1.3 above for the important distinction between its sourced classical
*categories* and this implementation's own *point values* within them), and
KP sub-lords/Cusp chart (Placidus house cusps — the one part of this whole
build where tests caught two real bugs, not just confirmed correctness) are
**all done**. Only the context-attach step of Ask Jay remains as a follow-up
on this same foundation (chart/Dasha/Panchang/transits all now exist to
attach), plus dedicated `GET` endpoints for chart/Dasha data that's already
computed but not yet exposed standalone.

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

**Ask Jay and Subscription are wired to real data.** New `ConsultApi` and
`SubscriptionApi` services. Ask Jay verified live end-to-end in the browser
(asked a real question, got a real question ID, opened the real chat thread,
sent a follow-up message, saw it in My Questions with a correct relative
timestamp). Along the way, caught and fixed two more real bugs:
- `ask_jay_screen.dart`'s question textarea had the same non-uniform-`Border`
  + `borderRadius` crash originally found in `glass_card.dart` — it was
  silently breaking the input field's rendering (no hint text, no typed
  text visible). Fixed the same way: uniform border + a separate accent strip.
- Timestamps from the backend (`createdAt` etc.) round-trip through
  MySQL/EF Core without a `Z` suffix even though they're UTC, so Dart's
  `DateTime.parse` misread them as local time (a question asked seconds ago
  showed "5h ago"). Fixed by reinterpreting the parsed components as UTC
  before converting to local time.

**Also testing on a physical iPhone (at the user's request), alongside Chrome
web.** This surfaced a real device-networking gap that doesn't exist for web/
simulator testing:
- `ApiConfig.baseUrl` now accepts a `--dart-define=API_BASE_URL=...`
  override, since a physical device can't reach "localhost" (that's the
  device itself) — it needs the dev machine's LAN IP.
- The backend has to bind to `0.0.0.0`, not `localhost`, or the phone can't
  reach it at all (`dotnet run --urls http://0.0.0.0:5080`).
- iOS blocks local-network connections at the OS level unless the app
  declares `NSLocalNetworkUsageDescription` in `Info.plist` — without it,
  the permission prompt never appears and every connection silently fails
  with no error surfaced to Dart. This was missing and is the most likely
  root cause of a login that hung indefinitely on "Verifying" with zero
  requests ever reaching the backend. Added it, plus an ATS
  `NSAllowsLocalNetworking` exception (plain HTTP, not HTTPS). Awaiting
  confirmation from the user that login now works with the local-network
  permission prompt accepted.

**App-wide UI/UX visual refresh (Phase 0, cross-cutting) — done, within the
existing color palette only, per explicit user requirement.** Refreshed the
shared design-system components rather than touching all ~40 screens
individually — since `GlassCard` (39 usages), `GoldButton` (22), and
`IconChip` (22+) are used everywhere, the change cascades app-wide
automatically:
- `GlassCard` — 16px corners (was 12px), a subtle diagonal gradient fill
  instead of flat translucent, and a floating drop shadow for depth.
- `GoldButton` — now uses the gold gradient token that was already defined
  (`goldButtonGradient`, previously only used on chat bubbles) instead of a
  flat fill, plus a richer glow.
- `IconChip` — gradient background instead of flat tint, plus a defined
  border (previously borderless).
- `CosmicBackground` — added a faint top-center gold aura over the existing
  gradient for ambient depth.
- Also fixed a real inconsistency found along the way: Edit Birth Data's
  "Full Name" field used a flat bordered box while every other field on the
  same form used the glass-card treatment — unified it.
- Subscription's "POPULAR" badge now uses a gradient; "CURRENT" stays flat/
  muted as intended, for clearer visual hierarchy between the two states.

Verified live in the browser on 4 representative screens (Home, Edit Birth
Data, My Questions, Subscription) with no console errors, `flutter analyze`
clean. Not yet re-verified on the physical iPhone build (that build predates
this change).

**A full end-to-end pass across every backend endpoint (not just the Astro
Engine) was run on 2026-08-31**, exercising the real user journey live
against the dev database: auth (session/refresh), birth data + onboarding
draft, notification prefs + devices, the notifications inbox (mark
read/mark-all), Ask Jay (question + message thread), Subscription, and all
five Astro endpoints — plus deliberate edge cases: two-user ownership
isolation (a second user gets a clean 404 reading another user's question
thread or notifications, no data leakage), an unknown-birth-time profile
(Signal/transits/Dasha/Panchang all still work correctly; D60/KP/Cusp
correctly come back empty rather than fabricated), and the birth-data-edit
staleness bug described above, which this pass is what found it. Everything
else checked out correct. No other logical flaws surfaced.

**The Astro Engine screens are now wired to the frontend (2026-08-31).**
Two new backend endpoints (`GET /chart`, `GET /dasha` — the last piece
needed; see `backend/README.md` §Astro Engine) plus a backend-wide JSON
camelCase consistency fix (`Results.Ok(...)` auto-camelCases, but the manual
`JsonSerializer.Serialize` calls used for the Chart/Dasha DB-stored JSON and
`/transits/today` defaulted to PascalCase — would have produced mixed-case
JSON at different nesting depths in `/chart`'s response; fixed with a shared
`JsonConventions.CamelCase` options object). New `PanchangApi`, `SignalApi`,
`ChartApi` Flutter services; Panchang tab + Home's Panchang preview + Traffic
Signal screen + Kundli screen's five tabs (Planet/Dasha/Charts/KP/Cusp, "My
Kundli" only) all wired to real data — see Phase 3a's checklist above for the
full per-screen breakdown of what was dropped (fabricated flavor text/mock
interpretive copy with no backend equivalent) versus what was computed for
real from actual response fields (e.g. Vargottama is now a genuine D1-vs-D9
sign comparison, Dasha's "elapsed" meter a genuine date-fraction calculation).
Verified live end-to-end in a running browser session: dev-login, saved real
birth data through the already-wired Edit Birth Data screen, confirmed every
wired screen renders correct real values. **Found a real, higher-priority gap
while verifying**: the onboarding flow's "Casting Lagna Kundli" screen never
actually saves the birth data it collects (always was a themed mock, per its
own code comment — this predates today's work), so a brand-new user who
finishes onboarding gets no birth data saved and every Astro Engine screen
404s for them silently. Also found the "MY CHART" bottom-nav tab and "My
Kundli" (Home tile) are two separate, overlapping, never-reconciled screens —
only the latter got wired today.

**All of those gaps are now fixed, same day.** Onboarding threads real
name/DOB/time/place through the 4 steps into a new `OnboardingData`
scratchpad and actually calls `UserApi.saveBirthData` before entering the
shell; `my_chart_screen.dart` is wired to the same `/chart`+`/dasha` data as
"My Kundli" (painters deduplicated into `widgets/chart_painters.dart`,
fixing a real conjunct-planets-in-house-1 bug along the way);
`dasha_timeline_screen.dart` is wired too. Ask Jay's context-attach is built
(`POST /consult/questions` now joins chart+Dasha+Panchang+transits into
`ContextJson`, per `BACKEND_REQUIREMENTS.md`). Also found and fixed a more
serious latent bug while wiring the Dasha screens to real data: `GET
/dasha`'s `current` flag was a snapshot frozen at last-save time with no
scheduled job to refresh it, so it would silently go stale over time —
fixed by recomputing `current` live from each period's stored start/end on
every read instead, which needs no cron job at all. Backend: 200/200 tests
(3 new). Frontend: `flutter analyze` clean. **Not yet re-verified live** —
browser automation was unreliable this session (dev server answered `curl`
fine throughout; Chrome itself refused the connection and hit a tool-
targeting error on repeated attempts — an environment/extension issue, not
a code issue). Full details in Phase 3a's checklist above.

**Next up, in no particular required order:**
- A live browser pass through onboarding → Home/Panchang/Signal/Kundli once
  the browser-automation tooling issue above clears, to confirm what
  `flutter analyze` + the backend test suite can't: that it actually renders
  correctly end-to-end
- Phase 2 (Admin Panel) or 3b groundwork, or the nightly/monthly cron
  infrastructure for Panchang/transit/signal cache *pre-warming* (not
  correctness — see above; this is now purely a first-request-of-the-day
  latency optimization, not a staleness bug)
- Consider getting a professional astrologer's review of three flagged
  design choices before they reach real users: the Traffic Signal score's
  specific point values (categories are sourced classical rules; the numbers
  within them are this implementation's own first pass), D60's odd/even
  sign-reversal question (this uses the no-reversal convention; some
  software uses the reversed one), and the KP sub-lord/Cusp Placidus
  implementation generally, since it's the most mathematically intricate
  piece in the whole engine — see `backend/README.md` §Astro Engine
- Confirm the physical-device login fix worked (awaiting user confirmation)
- If wanted, rebuild and push the UI refresh to the physical iPhone too
- Get real credentials for Firebase/Places/payments so what's built can be
  fully exercised (real phone OTP, real place search, real checkout)
- Start Phase 2 (Admin Panel) or Phase 3b (Admin Panel Integration) groundwork
