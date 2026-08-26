# Traffic Jam Backend

.NET 10 modular monolith — see `../TASKLIST.md` Phase 1 for the full build
plan, and `../docs/BACKEND_REQUIREMENTS.md` / `../docs/API_REQUIREMENTS.md`
for the product spec this implements.

## Architecture

One ASP.NET Core Web API (`src/TrafficJam.Api`), internally organized into
modules under `Modules/` — `Auth`, `Users`, `Notifications`, `Consultation`,
and (not yet built) `Astro`. Not separate microservices — chosen deliberately
for build/deploy speed at this stage; the module boundaries are clean enough
to split out later if a module needs to scale independently.

- **Database:** MySQL 8, via EF Core + the Pomelo provider (pinned to 9.x — Pomelo has no EF Core 10-compatible release yet)
- **Cache:** Redis, via StackExchange.Redis — connected and health-checked, not yet used by any module (nothing to cache until the Astro Engine exists)
- **Astro Engine:** Swiss Ephemeris via P/Invoke to the native C library — **on hold**, see "Astro Engine" below
- **Auth:** Firebase phone-OTP → our own short-lived JWT + rotating refresh token
- **Payments:** Razorpay/Stripe — interface built (`IPaymentGateway`), no real gateway wired in yet

## Local dev setup

```bash
# 1. Start MySQL + Redis
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
conflicting with it. Redis is on the standard 6379.

## Astro Engine — on hold pending a licensing decision

Swiss Ephemeris is dual-licensed: free under **AGPL-3.0** (which legally
requires publishing this entire backend's source code, since running it as a
network service triggers AGPL's obligations — not just distributing files),
or a paid **Swiss Ephemeris Professional License** from Astrodienst (no
public pricing; contact them directly) to stay closed-source.

This blocks: chart generation, Panchang, Dasha, the Traffic Signal score,
Vibe Meter, Color of the Day, Astro Insights — everything the frontend calls
"Heavy (Astro Engine)" in `BACKEND_REQUIREMENTS.md`. Everything else in this
README does **not** depend on it and is already built.

## What's built

| Module | Endpoints | Status |
|--------|-----------|--------|
| Auth | `POST /auth/session`, `POST /auth/refresh`, `POST /auth/otp/resend`, `GET /me`, `GET /config` | Done. Needs a real Firebase project to be end-to-end usable (see below) |
| Users | `GET/PUT /me/birth-data`, `PATCH /onboarding/draft`, `GET/PUT /me/notification-preferences`, `POST /me/devices`, `GET /places/autocomplete`, `GET /places/geocode` | Done. Places proxy needs a real Google Places API key |
| Notifications | `GET /notifications`, `POST /notifications/{id}/read`, `POST /notifications/read-all` | Done — inbox CRUD only; FCM push delivery isn't built (needs the same Firebase project as Auth) |
| Consultation | `GET /consult/plans`, `POST/GET /consult/questions`, `GET/POST /consult/questions/{id}/messages`, `GET /subscription`, `GET /subscription/plans`, `POST /subscription/checkout`, `POST /subscription/verify`, `POST /payments/checkout` | Done. Ask Jay's chart/Dasha/transit/Panchang context-attach is a `TODO(astro-engine)` stub (empty object) until the engine exists. Checkout/verify need a real payment gateway |
| Astro | — | **On hold**, see above |

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

36 tests, all integration-level against the real dev MySQL container (each
test class gets its own uniquely-named schema, so nothing collides or needs
manual cleanup) — not mocks standing in for the database. Covers:

- AES-256-GCM encryption round-trip, including a check that the *raw MySQL
  column* never contains plaintext (not just that the app-layer round-trip
  works, which could pass even if the converter were silently misconfigured)
- The full Auth flow: session creation, user upsert, JWT issuance, refresh
  rotation, the phone-re-link edge case above, and 401 handling
- Every User/Notification/Consultation endpoint: happy path, ownership
  checks (a user can't read another user's question thread or mark someone
  else's notification read), and the clean-503 path for unconfigured
  external services (Firebase, Places, payments)

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
