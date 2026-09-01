import { useEffect, useRef, useState } from "react";
import { api, ApiError } from "../lib/api";
import { IconClose, IconChevronDown } from "../components/Icons";
import { useToast } from "../lib/toast";

function FeaturesDropdown({
  value,
  onChange,
  options,
}: {
  value: string[];
  onChange: (v: string[]) => void;
  options: string[];
}) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const onDocClick = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener("mousedown", onDocClick);
    return () => document.removeEventListener("mousedown", onDocClick);
  }, []);

  const toggle = (f: string) => {
    onChange(value.includes(f) ? value.filter((x) => x !== f) : [...value, f]);
  };

  return (
    <div className="dropdown" data-open={open} ref={ref}>
      <button type="button" className="dropdown__trigger" onClick={() => setOpen((o) => !o)}>
        {value.length === 0 ? (
          <span className="dropdown__placeholder">Select features…</span>
        ) : (
          <span className="dropdown__chips">
            {value.map((f) => (
              <span key={f} className="chip">
                {f}
                <span
                  className="chip__remove"
                  onClick={(e) => {
                    e.stopPropagation();
                    toggle(f);
                  }}
                >
                  ×
                </span>
              </span>
            ))}
          </span>
        )}
        <IconChevronDown className={`dropdown__caret${open ? " dropdown__caret--open" : ""}`} />
      </button>
      {open && (
        <div className="dropdown__panel">
          {options.map((f) => (
            <label key={f} className="dropdown__option">
              <input type="checkbox" checked={value.includes(f)} onChange={() => toggle(f)} />
              <span>{f}</span>
            </label>
          ))}
        </div>
      )}
    </div>
  );
}

interface ConsultPlan {
  id: string;
  name: string;
  priceRupees: number;
  slaHours: number;
}

interface SubscriptionPlan {
  id: string;
  name: string;
  tier: string;
  cycle: string;
  priceRupees: number;
  features: string[];
}

export function Plans() {
  const [consultPlans, setConsultPlans] = useState<ConsultPlan[] | null>(null);
  const [subPlans, setSubPlans] = useState<SubscriptionPlan[] | null>(null);
  const [editConsult, setEditConsult] = useState<ConsultPlan | null>(null);
  const [editSub, setEditSub] = useState<SubscriptionPlan | null>(null);
  const toast = useToast();

  const load = () => {
    api.get<ConsultPlan[]>("/admin/plans/consult").then(setConsultPlans);
    api.get<SubscriptionPlan[]>("/admin/plans/subscription").then(setSubPlans);
  };

  useEffect(load, []);

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>Pricing</h1>
          <p>Live in the app the moment you save — no redeploy needed.</p>
        </div>
      </div>

      <h2 style={{ marginBottom: 14 }}>Ask Jay response priority</h2>
      {!consultPlans ? (
        <div className="center-spin">
          <div className="spinner" />
        </div>
      ) : (
        <div className="table-card" style={{ marginBottom: 36 }}>
          <div className="row-list">
            {consultPlans.map((p) => (
              <button
                key={p.id}
                className="row row--clickable"
                onClick={() => setEditConsult(p)}
              >
                <div className="row__main">
                  <div className="row__title">{p.name}</div>
                  <div className="row__sub">Response within {p.slaHours} hour{p.slaHours === 1 ? "" : "s"}</div>
                </div>
                <div className="row__meta serif" style={{ fontSize: 17, color: "var(--gold-deep)" }}>
                  ₹{p.priceRupees}
                </div>
              </button>
            ))}
          </div>
        </div>
      )}

      <h2 style={{ marginBottom: 14 }}>Subscription tiers</h2>
      {!subPlans ? (
        <div className="center-spin">
          <div className="spinner" />
        </div>
      ) : (
        <div className="table-card">
          <div className="row-list">
            {subPlans.map((p) => (
              <button
                key={p.id}
                className="row row--clickable"
                onClick={() => setEditSub(p)}
              >
                <div className="row__main">
                  <div className="row__title">{p.name}</div>
                  <div className="row__sub">{p.features.join(" · ")}</div>
                </div>
                <div className="row__meta serif" style={{ fontSize: 17, color: "var(--gold-deep)" }}>
                  {p.priceRupees === 0 ? "Free" : `₹${p.priceRupees}`}
                </div>
              </button>
            ))}
          </div>
        </div>
      )}

      {editConsult && (
        <ConsultDrawer
          plan={editConsult}
          onClose={() => setEditConsult(null)}
          onSaved={() => {
            setEditConsult(null);
            load();
            toast("Plan updated");
          }}
        />
      )}
      {editSub && (
        <SubDrawer
          plan={editSub}
          featureOptions={Array.from(new Set((subPlans ?? []).flatMap((p) => p.features)))}
          onClose={() => setEditSub(null)}
          onSaved={() => {
            setEditSub(null);
            load();
            toast("Plan updated");
          }}
        />
      )}
    </div>
  );
}

function ConsultDrawer({ plan, onClose, onSaved }: { plan: ConsultPlan; onClose: () => void; onSaved: () => void }) {
  const [name, setName] = useState(plan.name);
  const [price, setPrice] = useState(String(plan.priceRupees));
  const [sla, setSla] = useState(String(plan.slaHours));
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const save = async () => {
    setSaving(true);
    setError(null);
    try {
      await api.put(`/admin/plans/consult/${plan.id}`, { name, priceRupees: Number(price), slaHours: Number(sla) });
      onSaved();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Couldn't save.");
    } finally {
      setSaving(false);
    }
  };

  return (
    <>
      <div className="drawer-backdrop" onClick={onClose} />
      <div className="drawer">
        <div className="drawer__head">
          <h2 style={{ fontSize: 17 }}>Edit “{plan.name}”</h2>
          <button className="drawer__close" onClick={onClose}>
            <IconClose />
          </button>
        </div>
        <div className="drawer__body">
          {error && <div className="login-error">{error}</div>}
          <div className="field">
            <label>Name</label>
            <input value={name} onChange={(e) => setName(e.target.value)} />
          </div>
          <div className="field-row">
            <div className="field">
              <label>Price (₹)</label>
              <input type="number" min={0} value={price} onChange={(e) => setPrice(e.target.value)} />
            </div>
            <div className="field">
              <label>Response SLA (hours)</label>
              <input type="number" min={1} value={sla} onChange={(e) => setSla(e.target.value)} />
            </div>
          </div>
          <button className="btn btn--primary" onClick={save} disabled={saving || !name.trim()}>
            {saving ? "Saving…" : "Save"}
          </button>
        </div>
      </div>
    </>
  );
}

function SubDrawer({
  plan,
  featureOptions,
  onClose,
  onSaved,
}: {
  plan: SubscriptionPlan;
  featureOptions: string[];
  onClose: () => void;
  onSaved: () => void;
}) {
  const [name, setName] = useState(plan.name);
  const [price, setPrice] = useState(String(plan.priceRupees));
  const [features, setFeatures] = useState<string[]>(plan.features);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const save = async () => {
    setSaving(true);
    setError(null);
    try {
      await api.put(`/admin/plans/subscription/${plan.id}`, { name, priceRupees: Number(price), features });
      onSaved();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Couldn't save.");
    } finally {
      setSaving(false);
    }
  };

  return (
    <>
      <div className="drawer-backdrop" onClick={onClose} />
      <div className="drawer">
        <div className="drawer__head">
          <h2 style={{ fontSize: 17 }}>Edit “{plan.name}”</h2>
          <button className="drawer__close" onClick={onClose}>
            <IconClose />
          </button>
        </div>
        <div className="drawer__body">
          {error && <div className="login-error">{error}</div>}
          <div className="field">
            <label>Name</label>
            <input value={name} onChange={(e) => setName(e.target.value)} />
          </div>
          <div className="field">
            <label>Price (₹, {plan.cycle.toLowerCase()})</label>
            <input type="number" min={0} value={price} onChange={(e) => setPrice(e.target.value)} />
          </div>
          <div className="field">
            <label>Features</label>
            <FeaturesDropdown value={features} onChange={setFeatures} options={featureOptions} />
          </div>
          <button className="btn btn--primary" onClick={save} disabled={saving || !name.trim()}>
            {saving ? "Saving…" : "Save"}
          </button>
        </div>
      </div>
    </>
  );
}
