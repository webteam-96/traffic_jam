# Traffic Jam — Backend Requirements (per screen)

Companion to `API_REQUIREMENTS.md`. That doc lists the HTTP contract; **this doc
explains what the backend must actually _do_** — which service owns it, what it
computes or stores, what it caches, and why — screen by screen.

---

## Architecture (target)

```
                       ┌─────────────────────────────┐
   Flutter app  ──────▶│  NGINX API Gateway (TLS, RL) │
                       └──────────────┬──────────────┘
        ┌──────────────┬──────────────┼───────────────┬───────────────┐
        ▼              ▼              ▼               ▼               ▼
   Auth Service   User Service   Astro Engine    Consultation     Notification
  (Firebase +    (profile,       Service         Service          Service
   app JWT)       birth data)    (Swiss Ephem.)  (Q&A, chat,      (FCM, cron)
                                                  payments)
        └──────────────┴───────┬──────┴───────────────┴───────────────┘
                               ▼
                   MySQL 8 (encrypted)  +  Redis (cache)
```

**Stack (from the proposal):** .NET Core 8 (C#) REST API · MySQL 8 · Redis ·
Swiss Ephemeris (C lib, via P/Invoke or a sidecar) · Firebase Auth (phone OTP) ·
Firebase Cloud Messaging · a payment gateway (Razorpay/Stripe).

### The one component everything depends on — the **Astro Engine**
Almost every screen's data is produced here. It must compute, per user:

1. **Birth chart** (one-time, cached forever): Lagna, Moon/Sun signs, 9 planets
   (Surya…Ketu) with house placements, Navamsha (D9), Nakshatra. Needs
   `dob + tob + lat + lng + timezone`.
2. **Vimshottari Dasha** (recompute monthly): Maha/Antar/Pratyantar periods.
3. **Daily transits (Gochar)** (batch daily for all users): current planet
   positions mapped against each user's Moon & Lagna.
4. **Panchang** (cached daily per city/timezone): Tithi, Nakshatra, Yoga,
   Karana, Rahu Kaal, Abhijit, sunrise/sunset.
5. **Traffic Signal score** (daily per user): weighted composite —
   Moon transit **30%** + Panchang **25%** + Dasha **25%** + major transits
   **20%** → Green 70–100 / Yellow 40–69 / Red 0–39.

> Design rule: the client never computes astrology. Backend computes once,
> caches, and serves. This keeps every device consistent and the ephemeris
> (a native C library) server-side only.

---

## Cross-cutting concerns

| Concern | Requirement |
|---------|-------------|
| **Auth** | Firebase verifies phone/OTP; backend verifies the Firebase ID token, upserts the user, issues an app JWT (short-lived) + refresh token. |
| **Birth-data security** | Birth data is sensitive personal data under **India's DPDP Act 2023**. Store **AES-256 encrypted at rest** in MySQL; TLS 1.3 in transit; never log raw values; never send to third parties. |
| **Caching** | Redis: Panchang per `city:date`, transits per `user:date`, signal/vibe/color per `user:date`, chart per `user` (permanent), Dasha per `user:month`. |
| **Batch jobs** | Nightly cron computes daily transits, signal, vibe, panchang, and queues morning briefings (5:00 AM IST). |
| **Idempotency** | Payment + onboarding-complete endpoints are idempotent (client retry-safe). |
| **Rate limiting** | At the gateway; stricter on `/auth/*` and `/consult/questions`. |

---

## Per-screen backend requirements

Legend: **Heavy** = needs the Astro Engine · **CRUD** = simple read/write ·
**None** = static screen, no backend.

### Auth & Onboarding

| Screen | Backend work | Owner | Notes / why |
|--------|--------------|-------|-------------|
| Splash | **CRUD** | Auth/User | Validate JWT, return `/me` + `/config` so the app can route (onboarded? force-update?). |
| Login | **CRUD** | Auth | Verify Firebase ID token → upsert `users` row → issue app JWT. This is the identity trust boundary. |
| OTP | **CRUD** | Auth | Same exchange after OTP verified by Firebase. Optional resend rate-limit ledger. |
| Welcome | **None** | — | Static. |
| Identity / Birth Time | **None / CRUD** | User | Collected locally; optional `onboarding_drafts` row to resume. |
| Birth Place | **CRUD (proxy)** | User | Server proxies **Google Places** (key stays server-side) and geocodes to `lat/lng/timezone` — the three mandatory ephemeris inputs. |
| Calculating | **Heavy** | Astro Engine | `POST /onboarding/complete` runs the **one-time birth-chart generation** (Lagna/Moon/Navamsha, Nakshatra, first Dasha). Stored encrypted + cached permanently. This is the single most important backend step; every later screen reads its output. |

### Main tabs

| Screen | Backend work | Owner | Notes / why |
|--------|--------------|-------|-------------|
| Home | **Heavy (read cache)** | Astro Engine | Aggregates the day's precomputed signal + panchang + vibe into one payload. Values come from the nightly batch (Redis), so the call is a cache read, not a live computation. |
| Panchang | **Heavy (cache/day)** | Astro Engine | Tithi/Nakshatra/Yoga/Karana/Rahu Kaal/Abhijit/sunrise/sunset for the user's location+timezone. Cached per `city:date`; the same city shares one computation. |
| My Chart | **Heavy (cache/perm)** | Astro Engine | Serves the stored D1 chart + Graha Sphuta table + Dasha. Chart is permanent cache; Dasha refreshed monthly. |
| Ask Jay | **CRUD + context join** | Consultation | On submit, the backend **joins the user's chart + current Dasha + active transits + today's Panchang** into the question record before routing to an astrologer. Also serves plan pricing. |
| Profile | **CRUD** | User | `/me`, `/subscription`, `/me/birth-data` reads. |

### Daily-insight detail screens (all **Heavy**, all read that day's cached computation)

| Screen | Endpoint served | What the engine produced |
|--------|-----------------|--------------------------|
| Today's Signal | `/signal/today` | Weighted composite score + band + the 4-factor breakdown (30/25/25/20). The dial & meters are a direct render of this. |
| Auspicious Windows | `/muhurat/today` | Personalised Muhurat windows (Lagna lord + Moon + Dasha aware) + Rahu Kaal. |
| Vibe Meter | `/vibe/today` | Focus/Money/Relationship % from house lords, transits, Dasha. |
| Color of the Day | `/color/today` | Ruling-planet colour + rationale. |
| Astro Insights | `/insights` | Current Dasha interpretation + transit alerts + 7-day forecast. |
| Kundli viewer | `/chart?varga=` | D1 / Moon / D9 divisional charts from the stored chart. |
| Dasha Timeline | `/dasha/timeline` | Full Maha/Antardasha period list with dates. |
| Planet Strengths | `/chart/strengths` | Shadbala/strength per planet + benefic/malefic + life themes. |

### Ask-Jay flow

| Screen | Backend work | Owner | Notes / why |
|--------|--------------|-------|-------------|
| Chat | **CRUD + realtime** | Consultation | Message thread persistence; realtime delivery of the astrologer's reply via WebSocket or FCM data-push. Enforces SLA timers (2–4 h standard, 30 min premium). |
| My Questions | **CRUD** | Consultation | List questions with status/category. |

### Remedies

| Screen | Backend work | Owner | Notes / why |
|--------|--------------|-------|-------------|
| Remedies | **Heavy + Content** | Astro Engine + Content | Trigger conditions (weak planet in transit, hard Dasha, tough aspects, bad Panchang) select remedies from the Content DB and **personalise** them to the user's weak planets. Serves mantra `audioUrl` from object storage. |

### Account

| Screen | Backend work | Owner | Notes / why |
|--------|--------------|-------|-------------|
| Notifications inbox | **CRUD** | Notification | Feed + read state. |
| Edit Birth Data | **Heavy (regenerate)** | User + Astro Engine | Saving new birth data **invalidates the cached chart and regenerates everything** (chart, Dasha, all daily derivations) — because every reading depends on it. |
| Notification Prefs | **CRUD** | Notification | Persist toggles; (un)subscribe FCM topics; adjust the per-user schedule for briefings/warnings. |
| Subscription / Paywall | **CRUD + payments** | Consultation/Payments | Plans, checkout order creation, payment verification, and a **gateway webhook** (`/webhooks/payments`) to reconcile renewals/cancellations and flip the user's tier. Tier gates premium features across the app. |

---

## Scheduled jobs (cron)

| Job | Schedule | Purpose |
|-----|----------|---------|
| Daily transit + signal + vibe + color batch | ~03:00 IST | Precompute per-user daily derivations so tab loads are cache reads. |
| Panchang precompute | ~03:00 IST | One computation per active city/timezone for the day. |
| Morning Briefing queue | 05:00 IST | Build + queue FCM "🟢 GREEN day…" pushes (6–7 AM delivery). |
| Rahu Kaal warnings | rolling | Fire 15 min before each user's Rahu Kaal. |
| Dasha refresh | monthly | Recompute Maha/Antar/Pratyantar boundaries. |
| Subscription reconciliation | hourly | Sync gateway state, handle expiries. |

---

## Data model (highlights)

| Table | Key columns | Notes |
|-------|-------------|-------|
| `users` | id, phone (hashed), firebase_uid, name, avatar_url, created_at | |
| `birth_data` | user_id, dob, tob, unknown_time, place, lat, lng, timezone | **AES-256 encrypted** |
| `charts` | user_id, d1_json, d9_json, moon_json, nakshatra, ayanamsa | permanent cache |
| `dashas` | user_id, maha, antar, pratyantar, valid_month | refreshed monthly |
| `daily_signal` | user_id, date, score, band, breakdown_json | from batch |
| `panchang_cache` | city, date, tithi…rahu_kaal…sunrise/sunset | shared per city |
| `questions` | id, user_id, domain, text, context_json, plan, status, sla_at | context = chart+dasha+transit+panchang snapshot |
| `messages` | question_id, sender, text, created_at | chat thread |
| `subscriptions` | user_id, tier, cycle, renews_at, gateway_ref | |
| `notification_prefs` | user_id, morning, rahu_kaal, events, dasha, remedies | |
| `devices` | user_id, fcm_token, platform | for push |
| `remedies_content` | id, type, title, detail, trigger_rule, audio_url | Content DB |

---

## Security & compliance checklist

- [ ] AES-256 at rest for `birth_data` (sensitive personal data, DPDP Act 2023).
- [ ] TLS 1.3 everywhere; certificate pinning in the Flutter app.
- [ ] Firebase-verified identity; app JWT short-lived + refresh rotation.
- [ ] Data export & delete endpoints (DPDP / GDPR right to erasure).
- [ ] No birth data to third parties; Places/geocoding proxied server-side.
- [ ] PII never logged; audit + pen-test quarterly post-launch.

---

## Screen → backend intensity at a glance

| Intensity | Screens |
|-----------|---------|
| **None (static)** | Welcome |
| **Light CRUD** | Splash, Login, OTP, Identity, Birth Time, Profile, My Questions, Notifications inbox, Notification Prefs |
| **Proxy** | Birth Place (Google Places) |
| **Heavy (Astro Engine)** | Calculating, Home, Panchang, My Chart, Today's Signal, Auspicious Windows, Vibe Meter, Color of the Day, Astro Insights, Kundli, Dasha Timeline, Planet Strengths, Remedies, Edit Birth Data |
| **CRUD + payments** | Ask Jay, Subscription |
| **CRUD + realtime** | Chat |
