# Traffic Jam — Control Room (Admin Panel)

A web dashboard for the Traffic Jam staff/astrologer side — the operational
surface the app's own users never see. Built with React + TypeScript + Vite,
hand-styled (no UI kit) to match the mobile app's exact design tokens
(`src/styles/tokens.css`, mirrored from `frontend/lib/theme/app_theme.dart`).

## What it does

- **Dashboard** — live counts (users, charts cast, pending questions/appointments, paying subscribers) and a recent-questions feed.
- **Ask Jay** — the queue of real user questions, each with the real chart/Dasha/Panchang/transit snapshot `ConsultationEndpoints.BuildContextSnapshotAsync` attaches, and a reply box that finally lets someone answer as `MessageSender.Astrologer` — before this admin panel existed, that enum value had no endpoint that could ever set it.
- **Appointments** — the Book Appointment queue, with one-click status triage (Pending → Confirmed/Completed/Cancelled).
- **Users** — search (by name only — phone numbers are a one-way hash, by design, see `User.PhoneHash`) and a detail view (birth data status, tier, activity counts).
- **Remedies** — full CRUD over the `RemedyContent` catalog `GET /remedies` personalises from. Previously the only way to change a remedy was a new EF migration.
- **Pricing** — Ask Jay response-priority pricing and subscription tier pricing, both DB-backed (`ConsultPlanRow`/`SubscriptionPlanRow`) — edits go live in the app immediately, no redeploy.

## Running it

```bash
npm install
cp .env.example .env      # points at the backend; edit if it's not on localhost:5227
npm run dev
```

Requires the backend running (`backend/README.md`) with its migrations applied.

## Logging in

A dev-only admin account is seeded by the `AddAdminPanel` migration:

- **Email:** `admin@trafficjam.life`
- **Password:** `TrafficJam2026!`

Change or remove this account before any real deployment — see the seed's
comment in `AppDbContext.OnModelCreating`.

## Auth model

Admin JWTs are issued by the same `JwtService` the consumer app uses, but
carry a `ClaimTypes.Role = "admin"` claim a consumer token never has (see
`IssueAdminAccessToken`). Every `/admin/*` endpoint requires the `AdminOnly`
authorization policy, which checks exactly that claim — a consumer's own
token can never reach these endpoints, and an admin token can never
authenticate as a consumer (there's no `User` row behind it).

There's no refresh-token flow for admin sessions yet (access tokens expire
per `Jwt:AccessTokenMinutes`, same as consumer tokens) — on expiry, the
panel drops back to the login screen rather than silently refreshing. Worth
revisiting if staff sessions turn out to be long-running.
