import { useEffect, useRef, useState } from "react";
import { api, ApiError } from "../lib/api";
import { IconClose } from "../components/Icons";
import { StatusPill } from "../components/StatusPill";
import { useToast } from "../lib/toast";
import { ImageCropper } from "../components/ImageCropper";

interface Profile {
  name: string;
  title: string;
  bio: string;
  philosophy: string;
  expertise: string;
  imageDataUri: string | null;
}

interface Review {
  id: string;
  quote: string;
  author: string;
  sortOrder: number;
  rating: number | null;
  status: "Pending" | "Approved" | "Rejected";
  /** True when a user submitted it from the app rather than the team writing it. */
  isFromUser: boolean;
  createdAt: string;
}

export function Astrologer() {
  const [profile, setProfile] = useState<Profile | null>(null);
  const [reviews, setReviews] = useState<Review[] | null>(null);
  const [editing, setEditing] = useState<Review | "new" | null>(null);
  const toast = useToast();

  const load = () =>
    api.get<{ profile: Profile; reviews: Review[] }>("/admin/astrologer").then((data) => {
      setProfile(data.profile);
      setReviews(data.reviews);
    });

  useEffect(() => {
    load();
  }, []);

  const pending = reviews?.filter((r) => r.status === "Pending") ?? [];

  const moderate = async (id: string, action: "approve" | "reject") => {
    try {
      await api.post(`/admin/astrologer/reviews/${id}/${action}`, {});
      toast(action === "approve" ? "Review published" : "Review rejected");
      load();
    } catch (err) {
      toast(err instanceof ApiError ? err.message : "Couldn't update the review.");
    }
  };

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>About Jay</h1>
          <p>
            The profile, photo and reviews shown on the app's About Jay Kotecha screen. Edits go live
            immediately — no app release needed.
          </p>
        </div>
      </div>

      {!profile ? (
        <div className="center-spin">
          <div className="spinner" />
        </div>
      ) : (
        <ProfileForm profile={profile} onSaved={load} notify={toast} />
      )}

      <div className="page-head" style={{ marginTop: 32 }}>
        <div>
          <h1 style={{ fontSize: 20 }}>
            Client reviews
            {pending.length > 0 && (
              <span className="pill pill--pending" style={{ marginLeft: 10, fontSize: 12 }}>
                {pending.length} awaiting review
              </span>
            )}
          </h1>
          <p>
            Users submit these from the app. Nothing appears in the app until it's approved here.
            Lower sort order shows first.
          </p>
        </div>
        <button className="btn btn--primary" onClick={() => setEditing("new")}>
          + Add review
        </button>
      </div>

      {reviews && (
        <div className="table-card">
          <div className="row-list">
            {reviews.length === 0 && (
              <div className="row">
                <div className="row__main">
                  <div className="row__sub">No reviews yet.</div>
                </div>
              </div>
            )}
            {reviews.map((r) => (
              <div key={r.id} className="row">
                <button
                  className="row__main"
                  style={{ textAlign: "left", background: "none", border: 0, cursor: "pointer", padding: 0 }}
                  onClick={() => setEditing(r)}
                >
                  <div className="row__title">
                    {r.author}
                    {r.rating != null && (
                      <span style={{ marginLeft: 8, color: "var(--gold)" }}>
                        {"\u2605".repeat(r.rating)}
                        <span style={{ color: "var(--text-tertiary)" }}>
                          {"\u2606".repeat(5 - r.rating)}
                        </span>
                      </span>
                    )}
                    {r.isFromUser && (
                      <span className="row__meta" style={{ marginLeft: 8 }}>from a user</span>
                    )}
                  </div>
                  <div className="row__sub">{r.quote}</div>
                </button>
                <StatusPill status={r.status} />
                {r.status === "Pending" ? (
                  <div style={{ display: "flex", gap: 6, marginLeft: 10 }}>
                    <button
                      className="btn btn--primary"
                      style={{ padding: "5px 12px", fontSize: 13 }}
                      onClick={() => moderate(r.id, "approve")}
                    >
                      Approve
                    </button>
                    <button
                      className="btn"
                      style={{ padding: "5px 12px", fontSize: 13 }}
                      onClick={() => moderate(r.id, "reject")}
                    >
                      Reject
                    </button>
                  </div>
                ) : (
                  <span className="row__meta" style={{ minWidth: 32, textAlign: "right", marginLeft: 10 }}>
                    {r.sortOrder}
                  </span>
                )}
              </div>
            ))}
          </div>
        </div>
      )}

      {editing && (
        <ReviewDrawer
          review={editing === "new" ? null : editing}
          nextOrder={reviews?.length ?? 0}
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

function ProfileForm({
  profile,
  onSaved,
  notify,
}: {
  profile: Profile;
  onSaved: () => void;
  notify: (m: string) => void;
}) {
  const [form, setForm] = useState(profile);
  // Null until a new photo is cropped. The API treats a null image as "leave
  // the existing photo alone", so a text-only edit never clears it.
  const [newImage, setNewImage] = useState<string | null>(null);
  // The picked file, held while the cropper is open. Nothing is uploaded until
  // the crop is confirmed — the raw file itself never leaves the browser.
  const [cropping, setCropping] = useState<File | null>(null);
  const [saving, setSaving] = useState(false);
  const fileInput = useRef<HTMLInputElement>(null);

  const save = async () => {
    setSaving(true);
    try {
      await api.put("/admin/astrologer", { ...form, imageDataUri: newImage });
      notify("Profile updated");
      setNewImage(null);
      onSaved();
    } catch (err) {
      notify(err instanceof ApiError ? err.message : "Couldn't save the profile.");
    } finally {
      setSaving(false);
    }
  };

  const shown = newImage ?? form.imageDataUri;

  return (
    <div className="table-card" style={{ padding: 20 }}>
      {cropping && (
        <ImageCropper
          file={cropping}
          onCancel={() => {
            setCropping(null);
            if (fileInput.current) fileInput.current.value = "";
          }}
          onCropped={(dataUri) => {
            setNewImage(dataUri);
            setCropping(null);
          }}
        />
      )}
      <div style={{ display: "flex", gap: 20, alignItems: "flex-start", marginBottom: 18 }}>
        <div>
          {shown ? (
            <img
              src={shown}
              alt="Jay Kotecha"
              // Circular, matching how the app clips it — so the preview here
              // is what a user actually sees, not a square version of it.
              style={{ width: 96, height: 96, objectFit: "cover", borderRadius: "50%" }}
            />
          ) : (
            <div
              style={{
                width: 96,
                height: 96,
                borderRadius: "50%",
                background: "var(--surface-alt)",
                display: "grid",
                placeItems: "center",
                fontSize: 12,
                color: "var(--text-tertiary)",
              }}
            >
              No photo
            </div>
          )}
        </div>
        <div style={{ flex: 1 }}>
          <div className="field">
            <label>Profile photo</label>
            <input
              ref={fileInput}
              type="file"
              accept="image/*"
              onChange={(e) => {
                const file = e.target.files?.[0];
                if (file) setCropping(file);
              }}
            />
            <div style={{ fontSize: 12, color: "var(--text-tertiary)", marginTop: 6 }}>
              Pick any photo — you'll position it in the app's circle next. Leaving this alone
              keeps the current one.
            </div>
          </div>
          {shown && (
            <button
              className="btn"
              style={{ marginTop: 6 }}
              onClick={() => {
                setNewImage("");
                if (fileInput.current) fileInput.current.value = "";
              }}
            >
              Remove photo
            </button>
          )}
        </div>
      </div>

      <div className="field-row">
        <div className="field">
          <label>Name</label>
          <input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
        </div>
        <div className="field">
          <label>Title</label>
          <input value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} />
        </div>
      </div>

      <div className="field">
        <label>Biography — one paragraph per line</label>
        <textarea
          rows={8}
          value={form.bio}
          onChange={(e) => setForm({ ...form, bio: e.target.value })}
        />
      </div>

      <div className="field">
        <label>Philosophy pull-quote</label>
        <textarea
          rows={3}
          value={form.philosophy}
          onChange={(e) => setForm({ ...form, philosophy: e.target.value })}
        />
      </div>

      <div className="field">
        <label>Areas of expertise — one per line</label>
        <textarea
          rows={8}
          value={form.expertise}
          onChange={(e) => setForm({ ...form, expertise: e.target.value })}
        />
      </div>

      <button
        className="btn btn--primary"
        onClick={save}
        disabled={saving || !form.name.trim() || !form.bio.trim()}
      >
        {saving ? "Saving…" : "Save profile"}
      </button>
    </div>
  );
}

function ReviewDrawer({
  review,
  nextOrder,
  onClose,
  onSaved,
  notify,
}: {
  review: Review | null;
  nextOrder: number;
  onClose: () => void;
  onSaved: () => void;
  notify: (m: string) => void;
}) {
  const [form, setForm] = useState(
    review
      ? { quote: review.quote, author: review.author, sortOrder: review.sortOrder }
      : { quote: "", author: "", sortOrder: nextOrder },
  );
  const [saving, setSaving] = useState(false);

  const save = async () => {
    setSaving(true);
    try {
      if (review) {
        await api.put(`/admin/astrologer/reviews/${review.id}`, form);
      } else {
        await api.post("/admin/astrologer/reviews", form);
      }
      notify(review ? "Review updated" : "Review added");
      onSaved();
    } catch (err) {
      notify(err instanceof ApiError ? err.message : "Couldn't save the review.");
    } finally {
      setSaving(false);
    }
  };

  const remove = async () => {
    if (!review) return;
    setSaving(true);
    try {
      await api.delete(`/admin/astrologer/reviews/${review.id}`);
      notify("Review deleted");
      onSaved();
    } catch (err) {
      notify(err instanceof ApiError ? err.message : "Couldn't delete the review.");
      setSaving(false);
    }
  };

  return (
    <>
      <div className="drawer-backdrop" onClick={onClose} />
      <div className="drawer">
        <div className="drawer__head">
          <h2 style={{ fontSize: 17 }}>{review ? "Edit review" : "New review"}</h2>
          <button className="drawer__close" onClick={onClose}>
            <IconClose />
          </button>
        </div>
        <div className="drawer__body">
          <div className="field">
            <label>Quote</label>
            <textarea
              rows={5}
              value={form.quote}
              onChange={(e) => setForm({ ...form, quote: e.target.value })}
            />
          </div>
          <div className="field">
            <label>Author</label>
            <input
              value={form.author}
              onChange={(e) => setForm({ ...form, author: e.target.value })}
              placeholder="Rohan M., Software Architect"
            />
          </div>
          <div className="field">
            <label>Sort order</label>
            <input
              type="number"
              value={form.sortOrder}
              onChange={(e) => setForm({ ...form, sortOrder: Number(e.target.value) })}
            />
          </div>

          <div style={{ display: "flex", gap: 10, marginTop: 4 }}>
            <button
              className="btn btn--primary"
              onClick={save}
              disabled={saving || !form.quote.trim() || !form.author.trim()}
            >
              {saving ? "Saving…" : "Save"}
            </button>
            {review && (
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
