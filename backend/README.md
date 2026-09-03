# Traffic Jam Backend

.NET 10 modular monolith — see `../TASKLIST.md` Phase 1 for the full build
plan, and `../docs/BACKEND_REQUIREMENTS.md` / `../docs/API_REQUIREMENTS.md`
for the product spec this implements.

## Architecture

One ASP.NET Core Web API (`src/TrafficJam.Api`), internally organized into
modules under `Modules/` — `Auth`, `Users`, `Notifications`, `Consultation`,
`Astro`. Not separate microservices — chosen deliberately for build/deploy
speed at this stage; the module boundaries are clean enough to split out
later if a module needs to scale independently.

- **Database:** MySQL 8, via EF Core + the Pomelo provider (pinned to 9.x — Pomelo has no EF Core 10-compatible release yet)
- **Cache:** MySQL tables only (`PanchangCache`, `DailySignals`, Chart/Dasha) — no Redis. `GET /transits/today`/`/transits/upcoming` used to cache in Redis (per `user:date`); removed 2026-09-03. Two reasons: the hosting target (Windows IIS) can't run Redis, and — confirmed live on production the same day — `ConnectionStrings:Redis` pointing at `localhost:6379` doesn't resolve to a real Redis wherever this is actually deployed, so every Redis-touching endpoint (`/transits/today`, `/health`, and `PUT /me/birth-data`'s cache invalidation) hung for 8-19s and then 500'd, silently blocking new-user onboarding. The underlying computation is cheap in-memory ephemeris math that never needed caching in the first place — see "Astro Engine" below.
- **Astro Engine:** [Astronomy Engine](https://github.com/cosinekitty/astronomy) (MIT license), not Swiss Ephemeris — see "Astro Engine" below for why
- **Auth:** Firebase phone-OTP → our own short-lived JWT + rotating refresh token
- **Payments:** Razorpay/Stripe — interface built (`IPaymentGateway`), no real gateway wired in yet

## Local dev setup

```bash
# 1. Start MySQL
docker compose up -d

# 2. Apply migrations
cd src/TrafficJam.Api
dotnet tool install --global dotnet-ef --version 9.0.0   # once, if not already installed
export PATH="$PATH:$HOME/.dotnet/tools"
dotnet ef database update

# 3. Run the API
dotnet run
# → http://localhost:5080/health should return "Healthy"
```

MySQL is exposed on host port **3307** (not 3306) — this machine already had
a native MySQL install bound to 3306, so the container was remapped to avoid
conflicting with it.

**If `dotnet ef database update` fails with "Table 'X' already exists":**
the dev database's `__EFMigrationsHistory` table doesn't reflect what's
actually applied (discovered 2026-08-31 — the tables were originally created
via `EnsureCreated()`-style bootstrapping rather than tracked migrations, so
EF tries to replay every migration from `InitialCreate` onward). Fix: insert
rows into `__EFMigrationsHistory` for whichever migrations' schema changes
are already reflected in the live DB (check with `DESCRIBE <table>`), then
re-run `dotnet ef database update` to apply just the new one.

## Astro Engine — switched to Astronomy Engine (2026-08-31)

Swiss Ephemeris is dual-licensed: free under **AGPL-3.0** (which legally
requires publishing this entire backend's source code, since running it as a
network service triggers AGPL's obligations — not just distributing files),
or a paid **Swiss Ephemeris Professional License** from Astrodienst (no
public pricing; contact them directly) to stay closed-source. Rather than
wait on that business decision, the engine is built on **Astronomy Engine**
instead — MIT-licensed, pure C# (no P/Invoke), ~1 arcminute accuracy (vs.
Swiss Ephemeris's ~0.001 arcsecond — see `Modules/Astro/` doc comments for
why that gap doesn't matter for astrology-scale precision).

Since Astronomy Engine outputs tropical positions and has no house-system
function, `Modules/Astro/` owns two pieces Swiss Ephemeris would have given
for free: the Lahiri ayanamsa conversion (`AyanamsaService.cs`) and the
Ascendant/house calculation (`AscendantCalculator.cs`, found by numerically
searching the ecliptic for the horizon crossing using only Astronomy
Engine's own coordinate-rotation primitives — see its doc comment).

**Built:** the birth chart as `BACKEND_REQUIREMENTS.md` defines it — Lagna,
the 9 classical planets (Surya...Ketu) with sign/house/retrograde, Navamsha
(D9), Nakshatra+Pada, plus the Moon chart (Chandra Kundli). Wired into
`PUT /me/birth-data`, so saving birth data now computes and stores a real
chart (`AstroEngineServiceTests.cs`, `AyanamsaServiceTests.cs`,
`AscendantCalculatorTests.cs`, `VedicMathTests.cs` cover the math;
`AscendantCalculatorTests` validates against a real geometric fact —
at sunrise the Ascendant must equal the Sun's own longitude — rather than a
hand-derived "expected" number).

Also built: **Vimshottari Dasha** (`VimshottariDasha.cs`) — not a new
astronomy calculation, a fixed formula (Maha/Antar/Pratyantar, each the same
9-way proportional split applied recursively) on top of the birth chart's
Moon Nakshatra position. Wired into the same `PUT /me/birth-data` call.
Verified with unit tests (invariants like "no gaps, sums exactly to the
parent period" plus one hand-verified exact case) and live against the dev
database — a 1990-05-15 Mumbai birth's Rahu Mahadasha → Moon Antardasha →
Mars Pratyantardasha all landed exactly on 2026-08-31 as expected.

Also built: **Panchang** (`PanchangService.cs` + `PanchangNames.cs`) — the
daily almanac. Tithi/Nakshatra/Yoga/Karana are the same sidereal-longitude
arithmetic re-evaluated for today instead of birth (classical convention:
whatever's in effect at sunrise). Rahu Kaal/Yamaganda/Gulika aren't astronomy
at all — the daylight span divided into 8 equal parts, with a fixed weekday
lookup table saying which part; that table was cross-checked against an
independent open-source implementation rather than trusted from memory (see
`PanchangNames.cs`'s doc comment), since a wrong table would silently produce
a wrong "inauspicious time" warning. Abhijit is the same daylight span
divided into 15 parts, centered on solar noon. Each Tithi/Nakshatra/Yoga/
Karana's exact end-of-period moment is found by numerically searching forward
for the next boundary crossing — the same coarse-scan-then-bisect strategy
`AscendantCalculator` uses, applied over time instead of over the ecliptic.
Exposed as `GET /panchang/today`, cached per (city, date) in `PanchangCache`
(location comes from the signed-in user's own birth place — the app has no
separate "current city" concept yet) — a real cache-fill-on-first-request,
not the nightly ~03:00 IST precompute batch job `BACKEND_REQUIREMENTS.md`
describes, which is still a not-yet-built follow-up for pre-warming it.
Verified with unit tests (invariants like "Rahu Kaal falls within daylight,"
"Tithi and Karana never mathematically disagree since they're the same
underlying angle") plus the verified weekday table, and live against the dev
database, including confirming two different users in the same city on the
same day correctly share one cached row.

Also built: **daily transits (Gochar)** (`TransitService.cs`) — today's graha
positions (via the same `GrahaPositions.ComputeAll` primitive the birth chart
uses, factored out once a second consumer needed the exact same block) placed
into whole-sign houses counted from the user's own natal Lagna and Moon
(`VedicMath.HouseFromSign`, also newly shared between birth-chart and transit
house math). Exposed as `GET /transits/today` — not named in
API_REQUIREMENTS.md (transits there are a building block for
`/signal/today`/`/vibe/today`/`/insights`/Ask Jay's context-attach, none
built yet), added the same way other structurally-necessary undocumented
endpoints were (e.g. `POST /auth/refresh`). This is the **first real use of
Redis** in this backend — cached per `user:date` per BACKEND_REQUIREMENTS.md's
caching table, a real cache-fill-on-first-request rather than the nightly
batch job. Verified with unit tests and live against the dev database,
including a cross-check against a fresh, independently-built
`AstroEngineService` computation of "today as if it were a birth moment,"
and confirming the transiting Rahu/Ketu axis (Aquarius/Leo) and Saturn
(Pisces) match real current astrology for this period, not just internal
self-consistency.

Also built: **the Traffic Signal score** (`TrafficSignalService.cs` +
`TrafficSignalTables.cs`) — `GET /signal/today`, the flagship result
API_REQUIREMENTS.md describes. Genuinely different in kind from everything
above: Tithi, Dasha, Panchang, and transits each have one unambiguous
classical mathematical definition to implement correctly. Turning four
auspiciousness signals into a single weighted percentage does not — no
source gives a number for "how good is a Bhadra Tithi," only a category.
This implementation follows BACKEND_REQUIREMENTS.md's weights exactly (Moon
transit 30% + Panchang 25% + Dasha 25% + major transits 20%) and grounds
each factor's *category* in real, sourced classical rules — Chandra Bala
(Moon-from-Moon house favorability), the Nanda/Bhadra/Jaya/Rikta/Purna Tithi
cycle, the 9 classically inauspicious Nitya Yogas (Brihat Parashara Hora
Shastra), Naisargika Maitri (planetary natural friendship — deliberately
asymmetric, e.g. Moon considers Mercury a friend but Mercury considers Moon
an enemy, a real feature of the source table, not a bug), and Guru/Shani
Gochar house-from-Moon tables (including Sade Sati) — but the exact 0-100
*point value* assigned to each category is this implementation's own
documented first pass, not a claim of astrological authority. `TrafficSignalTables.cs`'s
doc comments separate sourced category from chosen number at every table.
Verified with unit tests (including one that reconstructs the exact expected
weighted arithmetic by hand and asserts the service matches it precisely,
not just "looks plausible") and live against the dev database, cross-checked
against the actual Panchang/Dasha/transit values those endpoints had
independently returned for the same birth data in earlier verification —
every sub-score matched by hand-calculation, e.g. the Panchang factor
(round(75×0.40 + 35×0.35 + 20×0.25) = 47) landed exactly on the live number.

Also built: **D10 (Dashamsha) and D60 (Shashtiamsha)** divisional charts,
the two Kundli-expansion charts the frontend's Charts tab already has a
toggle for. Each sign holds 10 (D10) or 60 (D60) equal parts; both formulas
live in `VedicMath.cs` and were cross-checked against an independent
open-source implementation (northtara/jyotishganit) rather than trusted from
memory. **D10** follows the classical odd/even starting-sign rule (odd signs
count from themselves, even signs from the 9th sign from themselves — worked
examples matched a live hand-calculation exactly, e.g. Sun's D1 position of
0°33' Taurus landed on 5°34' Capricorn in D10, precisely). **D60 is the one
genuinely disputed formula in this codebase** — some classical sources
describe an odd/even reversal for the 60 named deities that some (not all)
software implementations extend to reversing the sign mapping itself; this
uses the simpler uniform (no reversal) convention the cross-checked
implementation uses, documented as a chosen convention rather than settled
fact in `VedicMath.ShastiamshaSignIndex`'s doc comment — flagged in
TASKLIST.md as worth a professional astrologer's review alongside the
Traffic Signal score's point values. D60 also inherits the app's existing
product rule (already enforced in the frontend Kundli screen) that it needs
a genuinely exact birth time — a 0°30' D60 slice is narrow enough that the
Moon's ordinary motion crosses one roughly every 40 minutes, so an
approximate birth time would produce a specific-looking but essentially
arbitrary result; `ComputeBirthChart` returns `D60: null` when the user's
birth time is unknown (D10's much wider 3° slices don't have this problem
and are always computed). Verified with unit tests and live against the dev
database for both a known-time profile (D10 and D60 both populated, matched
by hand-calculation) and an unknown-time one (`D10Json` populated,
`D60Json: "[]"`).

Also built: **KP sub-lords and the Cusp chart** (`KpLordship.cs`,
`KpService.cs`) — the last two pieces of BACKEND_REQUIREMENTS.md's Astro
Engine list, which is now fully built (chart, Dasha, Panchang, transits,
Traffic Signal, D10/D60, and this). The genuinely new piece here, unlike the
KP sign/star/sub/sub-sub lordship chain (pure degree arithmetic — Sub Lord
reuses the exact same proportional-subdivision math as Dasha's Antardasha,
now shared via `VimshottariConstants.cs` since it's used by both), is
**Placidus house cusps** (`PlacidusHouseCalculator.cs`) — KP's house system,
distinct from the whole-sign houses used everywhere else in this app.
Placidus has no closed-form solution (professional software iterates), so
this uses the same technique as `AscendantCalculator` — numerically
searching via Astronomy Engine's own coordinate-rotation primitives rather
than hand-transcribing the classical trig chain. **This was also the one
piece in this whole Astro Engine build where the tests caught two real bugs
before they shipped**, not just confirmed correctness: a house-index mapping
bug (IC was wired as opposite the Ascendant instead of opposite the
Midheaven) and a fraction-convention mismatch between derivation and code
that had cusps 11 and 12 swapped — both caught by empirical ordering checks,
not just trusted from the math. Verified with unit tests (including cusp 1
cross-checked against the independently-built `AscendantCalculator`, cusp 10
checked against its own meridian-crossing definition, and every planet
landing in exactly one of the 12 cusp spans) and live against the dev
database — cusp 1's sidereal longitude matched, to 10 decimal places, the
Ascendant this same test birth data had produced when `AstroEngineService`
was first verified live, several features ago in this same session.

**`GET /chart` and `GET /dasha` are built** (`ChartEndpoints.cs`) — dedicated
reads over what `PUT /me/birth-data` already computed and stored (chart/Dasha/
KP/Cusp generation still all runs inside the PUT; these two just expose it).
Both `404` with `{error:{code:"NO_CHART"|"NO_DASHA",...}}` when no birth data
has been saved yet. `/chart` returns `ayanamsa`, `nakshatra` (Moon's, e.g.
"Revati-2"), `computedAt`, `ascendant`, `d1`/`d9`/`d10`/`d60` (each an array of
`{planet, signIndex, sign, degreeInSign, house, retrograde}` — `house` is only
populated for `d1` and `moonChart`, since the divisional charts only compute
each planet's varga *sign*, not a varga-Lagna house position), `moonChart`,
`kp`, and `cusps` (`kp`/`cusps` are `[]` when the birth time isn't known
exactly — see AstroEngineService's D60/KP doc comments for why). `/dasha`
returns `validMonth`, `maha`/`antar`/`pratyantar` (each `{lord, start, end,
current}`). Wired into the Flutter app's Kundli screen — see
`frontend`'s TASKLIST entry for the per-tab breakdown of what's shown.

Still not yet built: the Dasha table's `ValidMonth` and the Panchang/transit/
signal caches are all meant to be kept fresh by scheduled jobs (monthly and
nightly respectively) for users/cities that don't trigger a fresh computation
on their own — that cron infrastructure doesn't exist yet.

### JSON casing consistency (found while building `/chart`)

`Results.Ok(record)` (ASP.NET Core minimal APIs' default) auto-camelCases.
But the manual `JsonSerializer.Serialize(...)` calls used to store the Chart/
Dasha JSON blobs in MySQL — and, separately, `/transits/today`'s own manual
serialize call — defaulted to `JsonSerializer`'s own PascalCase default. Since
`/chart`'s response embeds those stored JSON blobs directly (parsed to
`JsonElement` and passed through, not re-mapped field-by-field), a client
would have seen the top-level wrapper fields (`ayanamsa`, `d1`, ...) in
camelCase but the nested planet/cusp objects inside them in PascalCase — a
real mixed-casing bug, caught in design review before `/chart` shipped, not
after. Fixed with a shared `JsonConventions.CamelCase` options object applied
to every manual `JsonSerializer.Serialize` call across the Astro module
(`UserEndpoints.RegenerateChartAndDashaAsync`, `TransitEndpoints`). This also
silently changed `/transits/today`'s response casing, which broke an existing
regression test that asserted PascalCase property names — updated to camelCase.

### Ask Jay's context-attach is built (2026-08-31)

`POST /consult/questions` now joins the user's chart + current Dasha + a
live today's-transits read + a live today's-Panchang read into `ContextJson`
before creating the question — the "context join" `BACKEND_REQUIREMENTS.md`
describes (§Ask Jay), previously a `TODO(astro-engine)` stub storing `"{}"`.
Chart and Dasha are read from the already-stored `Charts`/`Dashas` rows (no
recompute — same data `GET /chart`/`GET /dasha` expose); Panchang and
transits are computed live via `IPanchangService`/`ITransitService`, the same
pattern `SignalEndpoints` uses. The snapshot is `{chart: {ascendantSign,
sunSign, moonSign, nakshatra}, dasha: {maha, antar}, panchang: {tithi,
nakshatra, yoga, karana}, transits: [{planet, houseFromMoon}, ...]}` (major
planets only), serialized with the shared `JsonConventions.CamelCase`. Falls
back to `"{}"` — not fabricated placeholder data — when the user hasn't
saved birth data yet, so asking a question is never blocked on it. Nothing
currently reads `ContextJson` back out (it's meant for a future astrologer-
facing admin view, not yet built), so this isn't visible anywhere in the app
yet — verified via two new tests that assert directly on the stored row.

### `GET /dasha`'s stale `current` flag (found while wiring the Dasha screens, 2026-08-31)

Each stored Dasha period (`MahaJson`/`AntarJson`/`PratyantarJson`) carries a
`current` boolean — but it was a one-time snapshot computed by
`SerializeDashaPeriods` at whatever moment `PUT /me/birth-data` last ran, and
`GET /dasha` just passed the stored JSON straight through. There is no
scheduled job that refreshes it (the monthly cron job the Dasha entity's doc
comment calls out as not-yet-built). Practically: a user who saved their
birth data months ago would see a permanently wrong "current" Antardasha
(these run months) or Pratyantar (these run just weeks) on every screen that
reads `/dasha` — which, as of this session, is several (Kundli's Dasha tab,
My Chart, the Dasha timeline). Fixed by having `GET /dasha` recompute
`current` live on every read, comparing `DateTime.UtcNow` against each
period's own stored `start`/`end` (`ChartEndpoints.RefreshCurrentFlags`),
rather than trusting the stored flag. This is a strictly better fix than
building the missing cron job would have been: correctness no longer depends
on a scheduled job existing or firing on time, and it required no new
infrastructure. `/signal/today` was never affected — it already recomputes
Dasha fresh on every call via `IDashaService`, not from the stored entity.
One regression test seeds a deliberately stale stored flag and confirms the
response self-corrects.

### A real bug found via full end-to-end testing (2026-08-31): stale Signal/transit caches after a birth-data edit

Editing birth data always correctly regenerated `Charts` and `Dashas` (both
fully overwritten every `PUT /me/birth-data`), but `GET /signal/today`
(`DailySignals`, MySQL) and `GET /transits/today` (`transits:{userId}:*`,
Redis) were never invalidated by that edit — found by editing a test
profile's birth data to a completely different person (different decade,
different birth time) and observing both endpoints keep serving byte-for-byte
identical output from before the edit, no error, nothing to indicate
anything was wrong. `PUT /me/birth-data` now also deletes that user's
`DailySignals` rows and every matching Redis key on every save. `Panchang`
was deliberately left untouched — it's cached per city+date, not per user,
so a birth-data edit never made it wrong in the first place. Regression test:
`UserEndpointsTests.BirthData_Editing_InvalidatesStaleSignalAndTransitCaches`.
Verified both via the real integration-test host and live against the dev
database (edited a real profile through three different birth dates in a
row and confirmed the Dasha-lord driver text and transit house numbers
changed each time, with exactly one fresh `DailySignals` row surviving,
never a stale duplicate).

## What's built

| Module | Endpoints | Status |
|--------|-----------|--------|
| Auth | `POST /auth/session`, `POST /auth/refresh`, `POST /auth/otp/resend`, `GET /me`, `GET /config` | Done. Needs a real Firebase project to be end-to-end usable (see below) |
| Users | `GET/PUT /me/birth-data`, `PATCH /onboarding/draft`, `GET/PUT /me/notification-preferences`, `POST /me/devices`, `GET /places/autocomplete`, `GET /places/geocode` | Done. `PUT /me/birth-data` now also regenerates the real chart. Places proxy needs a real Google Places API key |
| Notifications | `GET /notifications`, `POST /notifications/{id}/read`, `POST /notifications/read-all` | Done — inbox CRUD only; FCM push delivery isn't built (needs the same Firebase project as Auth) |
| Consultation | `GET /consult/plans`, `POST/GET /consult/questions`, `GET/POST /consult/questions/{id}/messages`, `GET /subscription`, `GET /subscription/plans`, `POST /subscription/checkout`, `POST /subscription/verify`, `POST /payments/checkout` | Done, including Ask Jay's context-attach (see below). Checkout/verify need a real payment gateway |
| Astro | `GET /panchang/today`, `GET /transits/today`, `GET /signal/today`, `GET /chart`, `GET /dasha` (chart/Dasha/KP/Cusp generation runs inside `PUT /me/birth-data`; the two `GET`s above just read it back) | **Fully built** — birth chart (incl. D10/D60), Dasha, Panchang, transits, Traffic Signal, and KP/Cusp are all done. Only the nightly/monthly cache-*pre-warming* cron job remains — not a correctness gap, see `GET /dasha`'s `current`-flag fix below |

## External credentials this backend needs before it's fully live

None of these are configured yet — every integration point is built behind a
clean interface that fails with an explicit, actionable error (503, not a
crash) until it's wired up:

1. **A Firebase project** (`Firebase:CredentialsPath` → a real service account JSON) — for `/auth/session` to verify phone-OTP tokens, and later for FCM push
2. **A Google Places API key** (`GooglePlaces:ApiKey`) — for `/places/autocomplete` and `/places/geocode`
3. **A payment gateway account** (Razorpay or Stripe) — for `/subscription/checkout`, `/subscription/verify`, `/payments/checkout`

## Birth data encryption

`birth_data` fields (`Dob`, `Tob`, `Place`, `Lat`, `Lng`) are AES-256-GCM
encrypted at rest via an EF Core value converter (`AppDbContext` +
`AesEncryptionService`) — application code reads/writes plain values, MySQL
only ever stores ciphertext. This satisfies the DPDP Act 2023 requirement in
`BACKEND_REQUIREMENTS.md`. The same protection covers the in-progress
onboarding draft (`OnboardingDrafts` table), since it holds the same
sensitive fields mid-entry.

The dev encryption key in `appsettings.Development.json` is safe to commit —
it's local-only. **Production must supply `Encryption:Key` via a secrets
manager or environment variable, never this file.** The same applies to
`Jwt:SigningKey`. Generate a real key with:

```bash
openssl rand -base64 32
```

## Auth design notes

- Access tokens are short-lived JWTs (15 min default); refresh tokens are
  opaque random values, stored only as a SHA-256 hash (never the raw value —
  same principle as `User.PhoneHash`), and **rotate on every use**: redeeming
  a refresh token revokes it and issues a new pair. A reused (already-revoked)
  refresh token is rejected.
- If the same phone number comes back under a *different* Firebase UID
  (reinstall, re-verification, SIM swap), `/auth/session` re-links it to the
  existing user rather than trying to insert a second row and crashing on
  the unique index on `PhoneHash` — a real bug the test suite caught (see
  `AuthFlowTests.Session_WithSamePhoneNewFirebaseUid_RelinksTheExistingUser`).

## Tests

```bash
dotnet test
```

191 tests — a mix of integration tests against the real dev MySQL container
(each test class gets its own uniquely-named schema, so nothing collides or
needs manual cleanup) and unit tests for the Astro math. Covers:

- AES-256-GCM encryption round-trip, including a check that the *raw MySQL
  column* never contains plaintext (not just that the app-layer round-trip
  works, which could pass even if the converter were silently misconfigured)
- The full Auth flow: session creation, user upsert, JWT issuance, refresh
  rotation, the phone-re-link edge case above, and 401 handling
- Every User/Notification/Consultation endpoint: happy path, ownership
  checks (a user can't read another user's question thread or mark someone
  else's notification read), and the clean-503 path for unconfigured
  external services (Firebase, Places, payments)
- Astro Engine, Vimshottari Dasha, and Panchang: see "Astro Engine" above

**The per-class database isolation claim above was actually broken until
2026-08-31** — `Program.cs` read `ConnectionStrings:MySql` into a local
variable *before* `builder.Build()` ran, which the test host's config
override never got composed into in time, so every test run was silently
hitting the real dev database instead of its own `trafficjam_test_<guid>`
schema. Fixed by resolving the connection string lazily from the DI-provided
`IConfiguration` inside `AddDbContext`'s options callback instead. Also added
proper teardown (`TrafficJamApiFactory.Dispose`) so those per-run schemas get
dropped afterward instead of accumulating forever — DI-registered overrides
(like the fake Firebase verifier) were never affected, only raw config reads.

Requires `docker compose up -d` to be running. Test classes run sequentially
(`AssemblyInfo.cs` disables cross-class parallelization) — even with unique
per-class database names, concurrent DDL (`EnsureCreated`/`EnsureDeleted`)
against the same MySQL *server* contends on internal metadata locks and
produced spurious failures under parallel execution.

## Known deviations from the original proposal doc

- **.NET 10, not .NET 8** — .NET 8 wasn't installed on this machine and .NET
  10 is itself an LTS release with a longer support window; there's no
  existing .NET 8 infrastructure this needs to match.
- **Modular monolith, not 5 separate microservices** — see Architecture above.
- **Astro Engine on hold** — see above; needs a licensing decision, not a technical one.
