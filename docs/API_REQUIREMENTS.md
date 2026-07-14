# Traffic Jam — API Requirements (per screen)

This document lists **every REST API each screen needs, and why**. It is the
contract the Flutter frontend (in `frontend/`) will consume. The UI today ships
with mocked/inline data; each mock maps to one endpoint below.

---

## Conventions

| Item | Value |
|------|-------|
| Base URL | `https://api.trafficjam.app/v1` |
| Format | JSON, UTF-8. Timestamps ISO-8601 (UTC), money in paise (integer) |
| Auth | `Authorization: Bearer <appJWT>` on every endpoint except `/auth/*` and `/config` |
| Auth source | Firebase phone-OTP → Firebase ID token → exchanged for our app JWT |
| Errors | `{ "error": { "code": "STRING", "message": "..." } }` + HTTP status |
| Personalisation | All astro payloads are derived server-side from the signed-in user's **birth chart** — the client never sends chart data |
| Caching hints | Responses send `Cache-Control` / `ETag`; daily astro payloads are stable per user per day |

> Reason for a **server-computed** model: birth-time astrology (Swiss Ephemeris,
> Vimshottari Dasha, transits, Panchang) is heavy and must be identical across
> devices. The client only renders; it never calculates.

---

## 1. Auth & Onboarding

### 1.1 Splash (`splash_screen.dart`)
| Endpoint | Method | Reason |
|----------|--------|--------|
| `/config` | GET | App-version gate, feature flags, min-supported-build. Decides force-update. |
| `/me` | GET | Detect an existing session → route to Home; else route to Login. Returns 401 if no valid JWT. |

### 1.2 Login (`auth/login_screen.dart`)
| Endpoint | Method | Reason |
|----------|--------|--------|
| *(Firebase SDK)* | — | Phone number + OTP send/verify is handled **client-side by Firebase Auth**, not our API. This avoids us storing OTP logic and inherits Firebase anti-abuse. |
| `/auth/session` | POST | Body `{ firebaseIdToken }`. Backend **verifies the Firebase token**, creates/loads the user row, issues our app JWT. This is the trust boundary between Firebase identity and our data. |

### 1.3 OTP verify (`auth/otp_screen.dart`)
| Endpoint | Method | Reason |
|----------|--------|--------|
| *(Firebase SDK)* | — | `confirmationResult.confirm(code)` verifies the 6-digit code. |
| `/auth/session` | POST | Same exchange as 1.2 once Firebase returns a verified ID token. |
| `/auth/otp/resend` | POST | Optional server-side rate-limit ledger for the "Resend in 0:28" timer (Firebase also rate-limits). |

### 1.4 Welcome (`onboarding/welcome_screen.dart`)
No API — static value-proposition screen (Traffic Signal metaphor).

### 1.5 Identity / Birth Time / Birth Place (`onboarding/identity|birth_time|birth_place`)
| Endpoint | Method | Reason |
|----------|--------|--------|
| `/places/autocomplete?q=` | GET | **Birth Place** field. Server proxies Google Places so the Places key is never in the app, and returns `{ placeId, description, lat, lng, timezone }`. Lat/lng/timezone are mandatory inputs to the ephemeris. |
| `/places/geocode?placeId=` | GET | Resolve the chosen suggestion to precise coordinates + IANA timezone. |
| `/onboarding/draft` | PATCH | *(optional)* Persist name/DOB/time progressively so a dropped session can resume. |

> Name, DOB and time are collected locally and submitted together at 1.6.

### 1.6 Calculating (`onboarding/calculating_screen.dart`)
| Endpoint | Method | Reason |
|----------|--------|--------|
| `/onboarding/complete` | POST | Body `{ name, dob, tob, unknownTime, place{ lat, lng, timezone } }`. Kicks off the **one-time birth-chart generation** (Lagna/Moon/Navamsha, Nakshatra, current Dasha). The screen's animated checklist mirrors these server steps. |
| `/chart` | GET (poll or 202→ready) | Returns the generated chart when ready; the client advances to Home on success. |

---

## 2. Main Tabs

### 2.1 Home (`home_screen.dart`)
| Endpoint | Method | Reason |
|----------|--------|--------|
| `/dashboard/home` | GET | **Single aggregated call** to fill the 5 cards: today's Panchang (date, tithi, nakshatra), Celestial Vibe Meter (`vitality`, `intuition`, `focus` %), and the consultation-CTA config. One call keeps the dashboard snappy. |
| `/notifications?unread=1` | GET | Badge count for the bell icon in the app bar. |

> The 2×2 action tiles and Cosmic-Foundations grid are navigation only.

### 2.2 Panchang (`panchang_screen.dart`)
| Endpoint | Method | Reason |
|----------|--------|--------|
| `/panchang/today?date=` | GET | Returns `{ date, paksha, tithi{name,endsAt}, nakshatra{name,endsAt}, yoga{...}, karana{...}, rahuKaal{start,end}, abhijit{start,end}, sunrise, sunset }`. The **Rahu Kaal countdown** ticks client-side from `rahuKaal.end`; everything else is display. Cached per city+date. |

### 2.3 My Chart (`my_chart_screen.dart`)
| Endpoint | Method | Reason |
|----------|--------|--------|
| `/chart` | GET | Rashi (D1) house→planet map to draw the diamond, plus `grahaSphuta[]` = `{ graha, rashi, degrees, nakshatra }` for the table, and `ayanamsa/sidereal` flag. |
| `/dasha` | GET | Vimshottari card: `{ mahadasha, antardasha, antardashaProgress, mahadashaEndsAt }`. |
| `/insights/weekly` | GET | "Weekly Insight — The Transit of Saturn" card copy. |

### 2.4 Ask Jay (`ask_jay_screen.dart`)
| Endpoint | Method | Reason |
|----------|--------|--------|
| `/consult/plans` | GET | Standard (₹99) / Priority (₹299) pricing + SLA, so pricing is server-controlled. |
| `/consult/questions` | POST | Body `{ domain, question, planId }`. Backend **attaches the user's chart, current Dasha, active transits and today's Panchang as context** before routing to an astrologer. Returns `{ questionId, sla }`. |
| `/payments/checkout` | POST | Creates a Razorpay/Stripe order for the chosen plan → returns order token for the client SDK. |

### 2.5 Profile (`profile_screen.dart`)
| Endpoint | Method | Reason |
|----------|--------|--------|
| `/me` | GET | Cosmic Identity header, avatar. |
| `/subscription` | GET | ACTIVE PLAN card: `{ tier: "SAGA_PLUS", cycle, renewsAt, features[] }`. |
| `/me/birth-data` | GET | Birth Artifacts card (solar date, celestial time, geographic origin + map coords). |

---

## 3. Daily-Insight Detail Screens

### 3.1 Today's Signal (`details/traffic_signal_screen.dart`)
| Endpoint | Method | Reason |
|----------|--------|--------|
| `/signal/today` | GET | The flagship engine result: `{ score (0–100), band: green\|yellow\|red, label, guidance, breakdown: { moonTransit, panchang, dasha, transits }, weights: { 0.30, 0.25, 0.25, 0.20 } }`. The screen renders the dial + the four weighted meters directly from this. |

### 3.2 Auspicious Windows (`details/time_windows_screen.dart`)
| Endpoint | Method | Reason |
|----------|--------|--------|
| `/muhurat/today` | GET | `{ rahuKaal{start,end}, windows[]{ start, end, name, activities[] } }`. Windows are **personalised** (Lagna lord, Moon, active Dasha), not generic Panchang. |

### 3.3 Vibe Meter (`details/vibe_meter_screen.dart`)
| Endpoint | Method | Reason |
|----------|--------|--------|
| `/vibe/today` | GET | `{ focus, money, relationships }` each `{ percent, explanation }`, computed from the relevant house lords, transits and Dasha. |

### 3.4 Color of the Day (`details/color_of_day_screen.dart`)
| Endpoint | Method | Reason |
|----------|--------|--------|
| `/color/today` | GET | `{ color, hex, rulingPlanet, reason }` from the day-lord and the user's chart. |

### 3.5 Astro Insights (`details/astro_insights_screen.dart`)
| Endpoint | Method | Reason |
|----------|--------|--------|
| `/insights` | GET | `{ currentDasha{ maha, antar, interpretation }, planetaryEvents[]{ title, body, severity }, weeklyForecast[7]{ day, energy } }`. Feeds all three cards. |

### 3.6 Kundli viewer (`details/kundli_screen.dart`)
| Endpoint | Method | Reason |
|----------|--------|--------|
| `/chart?varga=D1\|MOON\|D9` | GET | Same chart service, parameterised by divisional chart, to drive the Lagna/Moon/Navamsha toggle. |

### 3.7 Dasha Timeline (`details/dasha_timeline_screen.dart`)
| Endpoint | Method | Reason |
|----------|--------|--------|
| `/dasha/timeline` | GET | Full ordered Mahadasha periods `[]{ planet, start, end }` with nested Antardasha for the active period → the vertical rail. |

### 3.8 Planet Strengths (`details/planet_strengths_screen.dart`)
| Endpoint | Method | Reason |
|----------|--------|--------|
| `/chart/strengths` | GET | `{ planets[]{ name, strength (Shadbala 0–1), nature: benefic\|malefic }, lifeThemes[] }` → the bar chart + themes list. |

---

## 4. Ask-Jay Flow

### 4.1 Chat (`ask/chat_screen.dart`)
| Endpoint | Method | Reason |
|----------|--------|--------|
| `/consult/questions/{id}/messages` | GET | Load the thread. |
| `/consult/questions/{id}/messages` | POST | Send a follow-up `{ text }`. |
| *(WebSocket / FCM)* | — | `wss://api.trafficjam.app/ws` or an FCM data-push delivers the astrologer's reply in realtime so the thread updates live. |

### 4.2 My Questions (`ask/my_questions_screen.dart`)
| Endpoint | Method | Reason |
|----------|--------|--------|
| `/consult/questions` | GET | History list `[]{ id, question, category, status: answered\|pending, createdAt }` for the status/category chips. |

---

## 5. Remedies

### 5.1 Remedies (`remedies/remedies_screen.dart`)
| Endpoint | Method | Reason |
|----------|--------|--------|
| `/remedies/today` | GET | `[]{ type: behavioural\|mantra\|color\|timing, title, detail, triggeredBy, audioUrl?, timing? }`. Remedies are **mapped to the user's weak planets / current transit challenges**, hence server-side. `audioUrl` streams the mantra. |
| `/remedies/{id}/remind` | POST | "Add all to reminders" → schedule an FCM reminder. |

---

## 6. Account

### 6.1 Notifications inbox (`notifications_screen.dart`)
| Endpoint | Method | Reason |
|----------|--------|--------|
| `/notifications` | GET | Alert feed `[]{ id, type, title, body, at, read }`. |
| `/notifications/{id}/read` | POST | Mark read (and the "mark all read" action). |

### 6.2 Edit Birth Data (`profile/edit_birth_data_screen.dart`)
| Endpoint | Method | Reason |
|----------|--------|--------|
| `/me/birth-data` | GET | Prefill the four fields. |
| `/me/birth-data` | PUT | Body `{ name, dob, tob, place{...} }`. **Re-triggers full chart regeneration** (SAVE CHANGES) because every reading depends on it. |

### 6.3 Notification Preferences (`profile/notification_prefs_screen.dart`)
| Endpoint | Method | Reason |
|----------|--------|--------|
| `/me/notification-preferences` | GET / PUT | Toggles `{ morningBriefing, rahuKaal, planetaryEvents, dashaReminders, remedyReminders }`. PUT updates **FCM topic subscriptions** and the server-side schedule. |

### 6.4 Subscription / Paywall (`profile/subscription_screen.dart`)
| Endpoint | Method | Reason |
|----------|--------|--------|
| `/subscription/plans` | GET | Free / Saga+ Monthly / Annual tiers + feature matrix. |
| `/subscription/checkout` | POST | `{ planId }` → payment order for the UPGRADE button. |
| `/subscription/verify` | POST | Confirm payment result and unlock the tier. |
| *(webhook — backend only)* | — | Gateway → `/webhooks/payments` reconciles renewals/cancellations (see backend doc). |

---

## 7. Push Notifications (server → device, no screen call)

These are **sent by the backend** (see backend doc §Notification Service) and land in the Notifications inbox / as system pushes. Listed here because the app must register an FCM token:

| Endpoint | Method | Reason |
|----------|--------|--------|
| `/me/devices` | POST | Register the FCM device token on login so the server can push. |
| *(FCM push)* | — | Morning Briefing (6–7 AM), Rahu Kaal warning (15 min before), planetary-event alerts, Dasha reminders, remedy reminders. |

---

## Endpoint summary

```
POST   /auth/session                 PUT  /me/birth-data
POST   /auth/otp/resend              GET  /me/notification-preferences
GET    /config                       PUT  /me/notification-preferences
GET    /me                           POST /me/devices
GET    /places/autocomplete          GET  /notifications
GET    /places/geocode               POST /notifications/{id}/read
POST   /onboarding/complete          GET  /consult/plans
GET    /chart  (?varga=)             POST /consult/questions
GET    /chart/strengths              GET  /consult/questions
GET    /dashboard/home               GET  /consult/questions/{id}/messages
GET    /panchang/today               POST /consult/questions/{id}/messages
GET    /signal/today                 GET  /remedies/today
GET    /muhurat/today                POST /remedies/{id}/remind
GET    /vibe/today                   GET  /subscription
GET    /color/today                  GET  /subscription/plans
GET    /insights                     POST /subscription/checkout
GET    /insights/weekly              POST /subscription/verify
GET    /dasha                        POST /payments/checkout
GET    /dasha/timeline               GET  /me/birth-data
```
