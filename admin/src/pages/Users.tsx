import { useEffect, useState } from "react";
import { api } from "../lib/api";
import { UserDrawer } from "../components/UserDrawer";

interface UserSummary {
  id: string;
  name: string | null;
  createdAt: string;
  hasBirthData: boolean;
  tier: string;
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

