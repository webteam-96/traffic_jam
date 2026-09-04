import { useEffect, useState } from "react";
import { api, ApiError } from "../lib/api";
import { StatusPill } from "../components/StatusPill";
import { UserDrawer } from "../components/UserDrawer";
import { useToast } from "../lib/toast";

interface Appointment {
  id: string;
  userId: string;
  userName: string | null;
  area: string;
  email: string;
  message: string | null;
  preferredDate: string;
  preferredTime: string;
  status: string;
  createdAt: string;
  birthPlace: string | null;
  dob: string | null;
  tob: string | null;
  unknownTime: boolean | null;
}

// e.g. "15 May 1990, 2:30 PM" / "15 May 1990, time unknown" — the birth
// details someone fulfilling the consultation actually needs, not shown
// anywhere else on this page.
function birthSummary(a: Appointment): string | null {
  if (!a.dob) return null;
  const dob = new Date(a.dob).toLocaleDateString(undefined, { day: "numeric", month: "short", year: "numeric" });
  const time = a.unknownTime || !a.tob
    ? "time unknown"
    : new Date(`1970-01-01T${a.tob}`).toLocaleTimeString(undefined, { hour: "numeric", minute: "2-digit" });
  return [dob, time, a.birthPlace].filter(Boolean).join(", ");
}

const FILTERS = ["All", "Pending", "Confirmed", "Completed", "Cancelled"];
const STATUS_OPTIONS = ["Pending", "Confirmed", "Completed", "Cancelled"];

export function Appointments() {
  const [filter, setFilter] = useState("Pending");
  const [items, setItems] = useState<Appointment[] | null>(null);
  const [openUserId, setOpenUserId] = useState<string | null>(null);
  const toast = useToast();

  const load = () => {
    setItems(null);
    const params = new URLSearchParams({ pageSize: "100" });
    if (filter !== "All") params.set("status", filter);
    api.get<{ appointments: Appointment[] }>(`/admin/appointments?${params}`).then((r) => setItems(r.appointments));
  };

  useEffect(load, [filter]);

  const updateStatus = async (id: string, status: string) => {
    try {
      await api.patch(`/admin/appointments/${id}/status`, { status });
      toast("Status updated");
      load();
    } catch (err) {
      toast(err instanceof ApiError ? err.message : "Couldn't update status.");
    }
  };

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>Appointments</h1>
          <p>Consultation requests from Book Appointment, ready to be scheduled.</p>
        </div>
        <div className="filter-tabs">
          {FILTERS.map((f) => (
            <button key={f} className={`filter-tab${filter === f ? " active" : ""}`} onClick={() => setFilter(f)}>
              {f}
            </button>
          ))}
        </div>
      </div>

      {!items ? (
        <div className="center-spin">
          <div className="spinner" />
        </div>
      ) : items.length === 0 ? (
        <div className="table-card">
          <div className="empty">No {filter !== "All" && filter.toLowerCase()} appointments right now.</div>
        </div>
      ) : (
        <div className="table-card">
          <div className="row-list">
            {items.map((a) => (
              // Row opens that person's full user drawer; the status dropdown
              // stops its own clicks from bubbling so changing a status
              // doesn't also open the drawer.
              <div
                key={a.id}
                className="row row--clickable"
                role="button"
                tabIndex={0}
                onClick={() => setOpenUserId(a.userId)}
                onKeyDown={(e) => {
                  if (e.key === "Enter" || e.key === " ") {
                    e.preventDefault();
                    setOpenUserId(a.userId);
                  }
                }}
              >
                <div className="row__main">
                  <div className="row__title">
                    {a.userName ?? "Unnamed user"} · {a.area}
                  </div>
                  <div className="row__sub">
                    {a.email}
                    {a.message ? ` — "${a.message}"` : ""}
                  </div>
                  <div className="row__sub" style={{ opacity: 0.75 }}>
                    {birthSummary(a) ?? "No birth data yet"}
                  </div>
                </div>
                <div className="row__meta">
                  {new Date(a.preferredDate).toLocaleDateString()} · {a.preferredTime.slice(0, 5)}
                </div>
                <StatusPill status={a.status} />
                <select
                  value={a.status}
                  onClick={(e) => e.stopPropagation()}
                  onChange={(e) => {
                    e.stopPropagation();
                    updateStatus(a.id, e.target.value);
                  }}
                  style={{
                    background: "var(--surface)",
                    border: "1px solid var(--border-strong)",
                    borderRadius: 6,
                    color: "var(--text-primary)",
                    fontSize: 12,
                    padding: "5px 8px",
                  }}
                >
                  {STATUS_OPTIONS.map((s) => (
                    <option key={s} value={s}>
                      {s}
                    </option>
                  ))}
                </select>
              </div>
            ))}
          </div>
        </div>
      )}

      {openUserId && <UserDrawer id={openUserId} onClose={() => setOpenUserId(null)} />}
    </div>
  );
}
