import { useEffect, useState } from "react";
import { api } from "../lib/api";
import { IconClose } from "../components/Icons";

interface UserSummary {
  id: string;
  name: string | null;
  createdAt: string;
  hasBirthData: boolean;
  tier: string;
}

interface UserDetail extends UserSummary {
  birthPlace: string | null;
  dob: string | null;
  unknownTime: boolean | null;
  questionCount: number;
  appointmentCount: number;
}

export function Users() {
  const [q, setQ] = useState("");
  const [items, setItems] = useState<UserSummary[] | null>(null);
  const [total, setTotal] = useState(0);
  const [openId, setOpenId] = useState<string | null>(null);

  useEffect(() => {
    const handle = setTimeout(() => {
      const params = new URLSearchParams({ pageSize: "50" });
      if (q.trim()) params.set("q", q.trim());
      api.get<{ users: UserSummary[]; totalCount: number }>(`/admin/users?${params}`).then((r) => {
        setItems(r.users);
        setTotal(r.totalCount);
      });
    }, 250);
    return () => clearTimeout(handle);
  }, [q]);

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>Users</h1>
          <p>{total ? `${total} people have signed up.` : "Everyone who's signed up."} Search is by name only — phone numbers are stored as a one-way hash and can't be looked up.</p>
        </div>
        <input
          placeholder="Search by name…"
          value={q}
          onChange={(e) => setQ(e.target.value)}
          style={{
            background: "var(--surface)",
            border: "1px solid var(--border-strong)",
            borderRadius: 8,
            color: "var(--text-primary)",
            padding: "9px 14px",
            fontSize: 13,
            width: 220,
          }}
        />
      </div>

      {!items ? (
        <div className="center-spin">
          <div className="spinner" />
        </div>
      ) : items.length === 0 ? (
        <div className="table-card">
          <div className="empty">No users match that search.</div>
        </div>
      ) : (
        <div className="table-card">
          <div className="row-list">
            {items.map((u) => (
              <button
                key={u.id}
                className="row row--clickable"
                onClick={() => setOpenId(u.id)}
              >
                <div className="row__main">
                  <div className="row__title">{u.name ?? "Unnamed user"}</div>
                  <div className="row__sub">{u.hasBirthData ? "Chart saved" : "No birth data yet"}</div>
                </div>
                <div className="row__meta">{new Date(u.createdAt).toLocaleDateString()}</div>
                <span className="pill pill--completed" style={{ opacity: u.tier === "Free" ? 0.55 : 1 }}>
                  {u.tier}
                </span>
              </button>
            ))}
          </div>
        </div>
      )}

      {openId && <UserDrawer id={openId} onClose={() => setOpenId(null)} />}
    </div>
  );
}

function UserDrawer({ id, onClose }: { id: string; onClose: () => void }) {
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
