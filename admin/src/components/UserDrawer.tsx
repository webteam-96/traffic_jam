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
export function UserDrawer({ id, onClose }: { id: string; onClose: () => void }) {
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
