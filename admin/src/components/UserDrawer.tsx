import { useEffect, useState } from "react";
import { api } from "../lib/api";
import { IconClose } from "./Icons";
import { StatusPill } from "./StatusPill";

export interface UserBooking {
  id: string;
  area: string;
  email: string;
  message: string | null;
  preferredDate: string;
  preferredTime: string;
  status: string;
  createdAt: string;
}

export interface UserQuestion {
  id: string;
  domain: string;
  text: string;
  status: string;
  createdAt: string;
}

export interface UserDetail {
  id: string;
  name: string | null;
  /// Null for accounts that predate the encrypted phone column — those
  /// numbers only ever existed as a hash. Fills in on their next sign-in.
  phone: string | null;
  createdAt: string;
  tier: string;
  birthPlace: string | null;
  dob: string | null;
  tob: string | null;
  unknownTime: boolean | null;
  questionCount: number;
  appointmentCount: number;
  bookings: UserBooking[];
  questions: UserQuestion[];
}

/// "2:30 PM" from the backend's "14:30:00".
function formatTime(t: string): string {
  return new Date(`1970-01-01T${t}`).toLocaleTimeString(undefined, { hour: "numeric", minute: "2-digit" });
}

/// "Tue, 3 Dec 2026" — the weekday matters when you're arranging a call.
function formatDate(d: string): string {
  return new Date(d).toLocaleDateString(undefined, {
    weekday: "short",
    day: "numeric",
    month: "short",
    year: "numeric",
  });
}

/// Slide-out panel with everything the admin panel knows about one user.
/// Lives here rather than inside Users.tsx because Appointments opens the
/// same panel when a request card is clicked — same person, same details,
/// no reason for two versions of it.
///
/// Everything below the identity block comes from the detail endpoint rather
/// than being passed in, so the panel is equally complete opened from the
/// Users list or from an appointment. `highlightBookingId` only says which
/// card to mark as "the one you clicked"; it never gates what's shown.
export function UserDrawer({
  id,
  highlightBookingId,
  onClose,
}: {
  id: string;
  highlightBookingId?: string;
  onClose: () => void;
}) {
  const [detail, setDetail] = useState<UserDetail | null>(null);

  useEffect(() => {
    setDetail(null);
    api.get<UserDetail>(`/admin/users/${id}`).then(setDetail);
  }, [id]);

  return (
    <>
      <div className="drawer-backdrop" onClick={onClose} />
      <div className="drawer">
        <div className="drawer__head">
          <div>
            <div className="eyebrow">User</div>
            <h2 style={{ fontSize: 17, marginTop: 4 }}>{detail?.name ?? "Unnamed user"}</h2>
          </div>
          <button className="drawer__close" onClick={onClose}>
            <IconClose />
          </button>
        </div>
        {!detail ? (
          <div className="center-spin">
            <div className="spinner" />
          </div>
        ) : (
          <div className="drawer__body">
            <div className="snapshot" style={{ marginBottom: 24 }}>
              <div className="snapshot__item" style={{ gridColumn: "1 / -1" }}>
                <div className="snapshot__label">Phone</div>
                <div className="snapshot__value">
                  {detail.phone ? (
                    <a href={`tel:${detail.phone}`} style={{ color: "inherit" }}>
                      {detail.phone}
                    </a>
                  ) : (
                    "Not on record yet"
                  )}
                </div>
              </div>
              <div className="snapshot__item">
                <div className="snapshot__label">Plan</div>
                <div className="snapshot__value">{detail.tier}</div>
              </div>
              <div className="snapshot__item">
                <div className="snapshot__label">Joined</div>
                <div className="snapshot__value">{new Date(detail.createdAt).toLocaleDateString()}</div>
              </div>
              <div className="snapshot__item">
                <div className="snapshot__label">Birth place</div>
                <div className="snapshot__value">{detail.birthPlace ?? "Not saved"}</div>
              </div>
              {/* Date and time of birth together — a reading can't be run off
                  the date alone, so the time belongs right beside it. */}
              <div className="snapshot__item">
                <div className="snapshot__label">Born</div>
                <div className="snapshot__value">
                  {detail.dob ? new Date(detail.dob).toLocaleDateString() : "—"}
                  {detail.dob && (detail.unknownTime || !detail.tob ? ", time unknown" : `, ${formatTime(detail.tob)}`)}
                </div>
              </div>
              <div className="snapshot__item">
                <div className="snapshot__label">Questions asked</div>
                <div className="snapshot__value">{detail.questionCount}</div>
              </div>
              <div className="snapshot__item">
                <div className="snapshot__label">Appointments booked</div>
                <div className="snapshot__value">{detail.appointmentCount}</div>
              </div>
            </div>

            {!detail.phone && (
              <p className="muted" style={{ fontSize: 12, marginBottom: 24 }}>
                This account signed up before we started keeping the number. It'll appear here the next time they sign in.
              </p>
            )}

            {detail.bookings.length > 0 && (
              <section style={{ marginBottom: 24 }}>
                <div className="eyebrow" style={{ marginBottom: 10 }}>
                  Appointments
                </div>
                {detail.bookings.map((b) => (
                  <article
                    key={b.id}
                    style={{
                      border: `1px solid var(--${b.id === highlightBookingId ? "gold-border" : "border"})`,
                      borderRadius: 8,
                      marginBottom: 8,
                      padding: "12px 14px",
                    }}
                  >
                    <div style={{ alignItems: "center", display: "flex", gap: 8, justifyContent: "space-between" }}>
                      <strong style={{ fontSize: 13 }}>{b.area}</strong>
                      <StatusPill status={b.status} />
                    </div>
                    <div style={{ fontSize: 13, marginTop: 6 }}>
                      {formatDate(b.preferredDate)} at {formatTime(b.preferredTime)}
                    </div>
                    {b.message && (
                      <p className="muted" style={{ fontSize: 12, marginTop: 6 }}>
                        “{b.message}”
                      </p>
                    )}
                    <div className="muted" style={{ fontSize: 11, marginTop: 6 }}>
                      <a href={`mailto:${b.email}`} style={{ color: "inherit" }}>
                        {b.email}
                      </a>{" "}
                      · booked {new Date(b.createdAt).toLocaleDateString()}
                    </div>
                  </article>
                ))}
              </section>
            )}

            {detail.questions.length > 0 && (
              <section>
                <div className="eyebrow" style={{ marginBottom: 10 }}>
                  Ask Jay questions
                </div>
                {detail.questions.map((q) => (
                  <article
                    key={q.id}
                    style={{
                      border: "1px solid var(--border)",
                      borderRadius: 8,
                      marginBottom: 8,
                      padding: "12px 14px",
                    }}
                  >
                    <div style={{ alignItems: "center", display: "flex", gap: 8, justifyContent: "space-between" }}>
                      <strong style={{ fontSize: 13 }}>{q.domain}</strong>
                      <StatusPill status={q.status} />
                    </div>
                    <p style={{ fontSize: 13, marginTop: 6 }}>{q.text}</p>
                    <div className="muted" style={{ fontSize: 11, marginTop: 6 }}>
                      asked {new Date(q.createdAt).toLocaleDateString()}
                    </div>
                  </article>
                ))}
              </section>
            )}
          </div>
        )}
      </div>
    </>
  );
}
