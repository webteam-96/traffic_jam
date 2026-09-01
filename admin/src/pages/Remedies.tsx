import { useEffect, useState } from "react";
import { api, ApiError } from "../lib/api";
import { IconClose } from "../components/Icons";
import { useToast } from "../lib/toast";

interface Remedy {
  id: string;
  type: string;
  title: string;
  detail: string;
  triggerRule: string;
  audioUrl: string | null;
}

const TYPES = ["mantra", "charity", "lifestyle"];
const TRIGGERS = ["general", "Sun", "Moon", "Mars", "Mercury", "Jupiter", "Venus", "Saturn", "Rahu", "Ketu"];

const emptyForm = { type: "lifestyle", title: "", detail: "", triggerRule: "general", audioUrl: "" };

export function Remedies() {
  const [items, setItems] = useState<Remedy[] | null>(null);
  const [editing, setEditing] = useState<Remedy | "new" | null>(null);
  const toast = useToast();

  const load = () => api.get<Remedy[]>("/admin/remedies").then(setItems);

  useEffect(() => {
    load();
  }, []);

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>Remedies</h1>
          <p>The catalog GET /remedies personalises by current Dasha lord — general ones, plus one per graha.</p>
        </div>
        <button className="btn btn--primary" onClick={() => setEditing("new")}>
          + Add remedy
        </button>
      </div>

      {!items ? (
        <div className="center-spin">
          <div className="spinner" />
        </div>
      ) : (
        <div className="table-card">
          <div className="row-list">
            {items.map((r) => (
              <button
                key={r.id}
                className="row row--clickable"
                onClick={() => setEditing(r)}
              >
                <div className="row__main">
                  <div className="row__title">{r.title}</div>
                  <div className="row__sub">{r.detail}</div>
                </div>
                <span className="pill pill--completed" style={{ textTransform: "capitalize" }}>
                  {r.type}
                </span>
                <span className="row__meta" style={{ minWidth: 62, textAlign: "right" }}>
                  {r.triggerRule}
                </span>
              </button>
            ))}
          </div>
        </div>
      )}

      {editing && (
        <RemedyDrawer
          remedy={editing === "new" ? null : editing}
          onClose={() => setEditing(null)}
          onSaved={() => {
            setEditing(null);
            load();
          }}
          notify={toast}
        />
      )}
    </div>
  );
}

function RemedyDrawer({
  remedy,
  onClose,
  onSaved,
  notify,
}: {
  remedy: Remedy | null;
  onClose: () => void;
  onSaved: () => void;
  notify: (m: string) => void;
}) {
  const [form, setForm] = useState(
    remedy ? { type: remedy.type, title: remedy.title, detail: remedy.detail, triggerRule: remedy.triggerRule, audioUrl: remedy.audioUrl ?? "" } : emptyForm,
  );
  const [saving, setSaving] = useState(false);

  const save = async () => {
    setSaving(true);
    try {
      const payload = { ...form, audioUrl: form.audioUrl.trim() || null };
      if (remedy) {
        await api.put(`/admin/remedies/${remedy.id}`, payload);
      } else {
        await api.post("/admin/remedies", payload);
      }
      notify(remedy ? "Remedy updated" : "Remedy created");
      onSaved();
    } catch (err) {
      notify(err instanceof ApiError ? err.message : "Couldn't save the remedy.");
    } finally {
      setSaving(false);
    }
  };

  const remove = async () => {
    if (!remedy) return;
    setSaving(true);
    try {
      await api.delete(`/admin/remedies/${remedy.id}`);
      notify("Remedy deleted");
      onSaved();
    } catch (err) {
      notify(err instanceof ApiError ? err.message : "Couldn't delete the remedy.");
      setSaving(false);
    }
  };

  return (
    <>
      <div className="drawer-backdrop" onClick={onClose} />
      <div className="drawer">
        <div className="drawer__head">
          <h2 style={{ fontSize: 17 }}>{remedy ? "Edit remedy" : "New remedy"}</h2>
          <button className="drawer__close" onClick={onClose}>
            <IconClose />
          </button>
        </div>
        <div className="drawer__body">
          <div className="field-row">
            <div className="field">
              <label>Type</label>
              <select value={form.type} onChange={(e) => setForm({ ...form, type: e.target.value })}>
                {TYPES.map((t) => (
                  <option key={t} value={t}>
                    {t}
                  </option>
                ))}
              </select>
            </div>
            <div className="field">
              <label>Trigger (Dasha lord, or general)</label>
              <select value={form.triggerRule} onChange={(e) => setForm({ ...form, triggerRule: e.target.value })}>
                {TRIGGERS.map((t) => (
                  <option key={t} value={t}>
                    {t}
                  </option>
                ))}
              </select>
            </div>
          </div>
          <div className="field">
            <label>Title</label>
            <input value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} />
          </div>
          <div className="field">
            <label>Detail</label>
            <textarea value={form.detail} onChange={(e) => setForm({ ...form, detail: e.target.value })} />
          </div>
          <div className="field">
            <label>Audio URL (optional)</label>
            <input value={form.audioUrl} onChange={(e) => setForm({ ...form, audioUrl: e.target.value })} placeholder="https://…" />
          </div>

          <div style={{ display: "flex", gap: 10, marginTop: 4 }}>
            <button className="btn btn--primary" onClick={save} disabled={saving || !form.title.trim() || !form.detail.trim()}>
              {saving ? "Saving…" : "Save"}
            </button>
            {remedy && (
              <button className="btn btn--danger" onClick={remove} disabled={saving}>
                Delete
              </button>
            )}
          </div>
        </div>
      </div>
    </>
  );
}
