import { useEffect, useState } from "react";
import { api } from "../lib/api";
import { IconClose } from "./Icons";

export interface UserDetail {
  id: string;
  name: string | null;
  createdAt: string;
  tier: string;
  birthPlace: string | null;
  dob: string | null;
  unknownTime: boolean | null;
  questionCount: number;
  appointmentCount: number;
}

/// Slide-out panel with everything the admin panel knows about one user.
/// Lives here rather than inside Users.tsx because Appointments opens the
/// same panel when a request card is clicked — same person, same details,
/// no reason for two versions of it.
///
/// `contactEmail` is passed in rather than fetched: a User row has no email
/// of its own (see User.cs — only a one-way phone hash and a Firebase uid).
/// Email is captured per-booking on the Appointment, so when this drawer is
/// opened from an appointment, that booking's email is the contact detail
/// worth surfacing here; opened from the Users list there simply isn't one.
export function UserDrawer({
  id,
  contactEmail,
  onClose,
}: {
  id: string;
  contactEmail?: string;
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
            <div className="snapshot" style={{ marginBottom: 20 }}>
              {contactEmail && (
                <div className="snapshot__item" style={{ gridColumn: "1 / -1" }}>
                  <div className="snapshot__label">Email (from their booking)</div>
                  <div className="snapshot__value">
                    <a href={`mailto:${contactEmail}`} style={{ color: "inherit" }}>
                      {contactEmail}
                    </a>
                  </div>
                </div>
              )}
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
              <div className="snapshot__item">
                <div className="snapshot__label">Date of birth</div>
                <div className="snapshot__value">
                  {detail.dob ? new Date(detail.dob).toLocaleDateString() : "—"}
                  {detail.unknownTime ? " (time unknown)" : ""}
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
            <p className="muted" style={{ fontSize: 12 }}>
              No phone number is shown here — it's stored as a one-way hash and genuinely can't be recovered, by design.
            </p>
          </div>
        )}
      </div>
    </>
  );
}
