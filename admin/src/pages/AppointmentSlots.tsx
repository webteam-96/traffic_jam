import { useEffect, useState } from "react";
import { api, ApiError } from "../lib/api";
import { useToast } from "../lib/toast";

interface Slot {
  id: string;
  startsAt: string;
  durationMinutes: number;
  isBooked: boolean;
  bookedBy: string | null;
}

/**
 * Quick-pick suggestions only — a shortcut for the common hours, not the range
 * of what's allowed. Any time can be added with the field beside them,
 * including ones outside these (2 AM for a client in another timezone, say).
 */
const SUGGESTED_HOURS = ["09:00", "10:00", "11:00", "12:00", "14:00", "15:00", "16:00", "17:00", "18:00", "19:00"];

/** "14:30" as "2:30 PM", for showing a picked time back. */
function readableTime(hhmm: string): string {
  const [h, m] = hhmm.split(":").map(Number);
  const hour12 = h % 12 === 0 ? 12 : h % 12;
  return `${hour12}:${String(m).padStart(2, "0")} ${h < 12 ? "AM" : "PM"}`;
}

/** Local YYYY-MM-DD for a date input, without the UTC shift toISOString gives. */
function inputDate(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

export function AppointmentSlots() {
  const [slots, setSlots] = useState<Slot[] | null>(null);
  const [date, setDate] = useState(() => inputDate(new Date(Date.now() + 86_400_000)));
  const [picked, setPicked] = useState<Set<string>>(new Set());
  const [duration, setDuration] = useState(30);
  const [customTime, setCustomTime] = useState("");
  const [saving, setSaving] = useState(false);
  const toast = useToast();

  const load = () => api.get<Slot[]>("/admin/appointment-slots").then(setSlots);

  useEffect(() => {
    load();
  }, []);

  const publish = async () => {
    if (picked.size === 0) return;
    setSaving(true);
    try {
      // Times are entered in the astrologer's own timezone and sent as UTC —
      // the API stores instants, so a slot means the same moment to a user in
      // any zone.
      const startsAt = [...picked].map((hhmm) => new Date(`${date}T${hhmm}:00`).toISOString());
      const result = await api.post<{ created: number; skipped: number }>(
        "/admin/appointment-slots",
        { startsAt, durationMinutes: duration },
      );
      toast(
        result.skipped > 0
          ? `${result.created} published, ${result.skipped} already existed`
          : `${result.created} slot${result.created === 1 ? "" : "s"} published`,
      );
      setPicked(new Set());
      load();
    } catch (err) {
      toast(err instanceof ApiError ? err.message : "Couldn't publish those slots.");
    } finally {
      setSaving(false);
    }
  };

  const remove = async (slot: Slot) => {
    try {
      await api.delete(`/admin/appointment-slots/${slot.id}`);
      toast("Slot removed");
      load();
    } catch (err) {
      toast(err instanceof ApiError ? err.message : "Couldn't remove that slot.");
    }
  };

  const toggle = (hhmm: string) =>
    setPicked((current) => {
      const next = new Set(current);
      if (next.has(hhmm)) next.delete(hhmm);
      else next.add(hhmm);
      return next;
    });

  // Grouped by day so a week of availability reads as a week, not a list.
  const byDay = new Map<string, Slot[]>();
  for (const slot of slots ?? []) {
    const key = new Date(slot.startsAt).toLocaleDateString(undefined, {
      weekday: "short", day: "numeric", month: "short", year: "numeric",
    });
    byDay.set(key, [...(byDay.get(key) ?? []), slot]);
  }

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>Availability</h1>
          <p>
            The slots users can book in the app. Only free, future slots are offered — once someone
            takes one it disappears for everyone else.
          </p>
        </div>
      </div>

      <div className="table-card" style={{ padding: 20, marginBottom: 28 }}>
        <div className="field-row">
          <div className="field">
            <label>Date</label>
            <input type="date" value={date} min={inputDate(new Date())} onChange={(e) => setDate(e.target.value)} />
          </div>
          <div className="field">
            <label>Length (minutes)</label>
            <input
              type="number"
              min={5}
              max={240}
              step={5}
              value={duration}
              onChange={(e) => setDuration(Number(e.target.value))}
            />
          </div>
        </div>

        <div className="field">
          <label>Times — your local timezone</label>
          <div style={{ display: "flex", flexWrap: "wrap", gap: 8, marginTop: 4 }}>
            {SUGGESTED_HOURS.map((h) => (
              <button
                key={h}
                className={`filter-tab${picked.has(h) ? " active" : ""}`}
                onClick={() => toggle(h)}
              >
                {readableTime(h)}
              </button>
            ))}
          </div>
        </div>

        <div className="field">
          <label>Or add any other time</label>
          <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
            <input
              type="time"
              value={customTime}
              style={{ maxWidth: 160 }}
              onChange={(e) => setCustomTime(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter" && customTime) {
                  toggle(customTime);
                  setCustomTime("");
                }
              }}
            />
            <button
              className="btn"
              disabled={!customTime}
              onClick={() => {
                toggle(customTime);
                setCustomTime("");
              }}
            >
              Add
            </button>
          </div>
          <div style={{ fontSize: 12, color: "var(--text-tertiary)", marginTop: 6 }}>
            Any time of day, including overnight — 02:00 is as valid as 14:00.
          </div>
        </div>

        {picked.size > 0 && (
          <div className="field">
            <label>Publishing on {date}</label>
            <div style={{ display: "flex", flexWrap: "wrap", gap: 8, marginTop: 4 }}>
              {[...picked].sort().map((h) => (
                <button
                  key={h}
                  className="filter-tab active"
                  title="Remove"
                  onClick={() => toggle(h)}
                >
                  {readableTime(h)} &times;
                </button>
              ))}
            </div>
          </div>
        )}

        <button className="btn btn--primary" onClick={publish} disabled={saving || picked.size === 0}>
          {saving ? "Publishing…" : `Publish ${picked.size || ""} slot${picked.size === 1 ? "" : "s"}`}
        </button>
      </div>

      {!slots ? (
        <div className="center-spin">
          <div className="spinner" />
        </div>
      ) : slots.length === 0 ? (
        <div className="table-card">
          <div className="empty">No slots published yet — users have nothing to book.</div>
        </div>
      ) : (
        [...byDay.entries()].map(([day, daySlots]) => (
          <div key={day} style={{ marginBottom: 22 }}>
            <div className="row__meta" style={{ marginBottom: 8, fontWeight: 600 }}>{day}</div>
            <div className="table-card">
              <div className="row-list">
                {daySlots.map((slot) => (
                  <div key={slot.id} className="row">
                    <div className="row__main">
                      <div className="row__title">
                        {new Date(slot.startsAt).toLocaleTimeString(undefined, {
                          hour: "numeric", minute: "2-digit",
                        })}
                        <span className="row__meta" style={{ marginLeft: 8 }}>
                          {slot.durationMinutes} min
                        </span>
                      </div>
                      {slot.isBooked && <div className="row__sub">Booked by {slot.bookedBy}</div>}
                    </div>
                    <span className={`pill pill--${slot.isBooked ? "completed" : "pending"}`}>
                      {slot.isBooked ? "Booked" : "Free"}
                    </span>
                    {!slot.isBooked && (
                      <button
                        className="btn"
                        style={{ padding: "5px 12px", fontSize: 13, marginLeft: 10 }}
                        onClick={() => remove(slot)}
                      >
                        Remove
                      </button>
                    )}
                  </div>
                ))}
              </div>
            </div>
          </div>
        ))
      )}
    </div>
  );
}
