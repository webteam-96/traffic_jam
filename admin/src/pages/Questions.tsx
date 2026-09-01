import { useEffect, useState } from "react";
import { api, ApiError } from "../lib/api";
import { StatusPill } from "../components/StatusPill";
import { IconClose, IconSend } from "../components/Icons";
import { useToast } from "../lib/toast";

interface QuestionSummary {
  id: string;
  userName: string | null;
  domain: string;
  question: string;
  plan: string;
  subscriptionPlanName: string;
  status: string;
  slaAt: string;
  createdAt: string;
}

interface Message {
  id: string;
  sender: string;
  text: string;
  createdAt: string;
}

interface QuestionDetail extends QuestionSummary {
  context: Record<string, unknown>;
  messages: Message[];
}

const FILTERS = ["All", "Pending", "Answered", "Closed"];

export function Questions() {
  const [filter, setFilter] = useState("Pending");
  const [items, setItems] = useState<QuestionSummary[] | null>(null);
  const [openId, setOpenId] = useState<string | null>(null);
  const toast = useToast();

  const load = () => {
    setItems(null);
    const params = new URLSearchParams({ pageSize: "100" });
    if (filter !== "All") params.set("status", filter);
    api.get<{ questions: QuestionSummary[] }>(`/admin/questions?${params}`).then((r) => setItems(r.questions));
  };

  useEffect(load, [filter]);

  const handleClosed = () => {
    setOpenId(null);
    load();
  };

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>Ask Jay</h1>
          <p>Real questions from real users, each with their chart context attached.</p>
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
          <div className="empty">No {filter !== "All" && filter.toLowerCase()} questions right now.</div>
        </div>
      ) : (
        <div className="table-card">
          <div className="row-list">
            {items.map((q) => (
              <button key={q.id} className="row row--clickable" onClick={() => setOpenId(q.id)}>
                <div className="row__main">
                  <div className="row__title">{q.question}</div>
                  <div className="row__sub">
                    {q.userName ?? "Unnamed user"} · {q.domain} · {q.plan}
                  </div>
                </div>
                <div className="row__meta">{new Date(q.createdAt).toLocaleDateString()}</div>
                <span
                  className="chip"
                  style={{ padding: "3px 11px", opacity: q.subscriptionPlanName === "Free" ? 0.55 : 1 }}
                >
                  {q.subscriptionPlanName}
                </span>
                <StatusPill status={q.status} />
              </button>
            ))}
          </div>
        </div>
      )}

      {openId && (
        <QuestionDrawer
          id={openId}
          onClose={() => setOpenId(null)}
          onReplied={load}
          onClosedQuestion={handleClosed}
          notify={toast}
        />
      )}
    </div>
  );
}

function QuestionDrawer({
  id,
  onClose,
  onReplied,
  onClosedQuestion,
  notify,
}: {
  id: string;
  onClose: () => void;
  onReplied: () => void;
  onClosedQuestion: () => void;
  notify: (m: string) => void;
}) {
  const [detail, setDetail] = useState<QuestionDetail | null>(null);
  const [reply, setReply] = useState("");
  const [sending, setSending] = useState(false);

  const reload = () => api.get<QuestionDetail>(`/admin/questions/${id}`).then(setDetail);

  useEffect(() => {
    setDetail(null);
    reload();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id]);

  const send = async () => {
    if (!reply.trim()) return;
    setSending(true);
    try {
      await api.post(`/admin/questions/${id}/reply`, { text: reply.trim() });
      setReply("");
      notify("Reply sent");
      await reload();
      onReplied();
    } catch (err) {
      notify(err instanceof ApiError ? err.message : "Couldn't send the reply.");
    } finally {
      setSending(false);
    }
  };

  const closeQuestion = async () => {
    await api.post(`/admin/questions/${id}/close`);
    notify("Question closed");
    onClosedQuestion();
  };

  const ctx = detail?.context ?? {};
  const hasContext = ctx && Object.keys(ctx).length > 0;
  const chart = (ctx as any).chart;
  const dasha = (ctx as any).dasha;
  const panchang = (ctx as any).panchang;

  return (
    <>
      <div className="drawer-backdrop" onClick={onClose} />
      <div className="drawer">
        <div className="drawer__head">
          <div>
            <div className="eyebrow">{detail?.domain}</div>
            <div style={{ display: "flex", alignItems: "center", gap: 8, marginTop: 4 }}>
              <h2 style={{ fontSize: 17 }}>{detail?.userName ?? "Unnamed user"}</h2>
              {detail && (
                <span
                  className="chip"
                  style={{ padding: "3px 11px", opacity: detail.subscriptionPlanName === "Free" ? 0.55 : 1 }}
                >
                  {detail.subscriptionPlanName}
                </span>
              )}
            </div>
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
            <div className="card card--tight" style={{ marginBottom: 18 }}>
              <p style={{ margin: 0, fontSize: 13.5, lineHeight: 1.6 }}>{detail.question}</p>
              <div style={{ marginTop: 10, display: "flex", gap: 8, alignItems: "center" }}>
                <StatusPill status={detail.status} />
                <span className="muted" style={{ fontSize: 11.5 }}>
                  {detail.plan} plan · SLA {new Date(detail.slaAt).toLocaleString()}
                </span>
              </div>
            </div>

            <div className="eyebrow" style={{ marginBottom: 8 }}>
              Chart context at time of asking
            </div>
            {hasContext ? (
              <div className="snapshot" style={{ marginBottom: 22 }}>
                {chart && (
                  <>
                    <Snap label="Ascendant" value={chart.ascendantSign} />
                    <Snap label="Sun / Moon" value={`${chart.sunSign} / ${chart.moonSign}`} />
                    <Snap label="Nakshatra" value={chart.nakshatra} />
                  </>
                )}
                {dasha && <Snap label="Dasha" value={`${dasha.maha} → ${dasha.antar}`} />}
                {panchang && <Snap label="Tithi / Yoga" value={`${panchang.tithi} / ${panchang.yoga}`} />}
              </div>
            ) : (
              <p className="muted" style={{ fontSize: 12.5, marginTop: 0, marginBottom: 22 }}>
                No birth data was saved when this question was asked.
              </p>
            )}

            <div className="eyebrow" style={{ marginBottom: 10 }}>
              Conversation
            </div>
            <div className="thread" style={{ marginBottom: 18 }}>
              {detail.messages.length === 0 && <p className="muted" style={{ fontSize: 12.5 }}>No replies yet.</p>}
              {detail.messages.map((m) => (
                <div key={m.id} className={`msg msg--${m.sender}`}>
                  {m.text}
                  <div className="msg__meta">{new Date(m.createdAt).toLocaleString()}</div>
                </div>
              ))}
            </div>

            {detail.status !== "Closed" && (
              <>
                <div className="field">
                  <label htmlFor="reply">Your reply</label>
                  <textarea id="reply" value={reply} onChange={(e) => setReply(e.target.value)} placeholder="Write a considered reply…" />
                </div>
                <div style={{ display: "flex", gap: 10 }}>
                  <button className="btn btn--primary" onClick={send} disabled={sending || !reply.trim()}>
                    <IconSend /> {sending ? "Sending…" : "Send reply"}
                  </button>
                  <button className="btn btn--ghost" onClick={closeQuestion}>
                    Close question
                  </button>
                </div>
              </>
            )}
          </div>
        )}
      </div>
    </>
  );
}

function Snap({ label, value }: { label: string; value: string }) {
  return (
    <div className="snapshot__item">
      <div className="snapshot__label">{label}</div>
      <div className="snapshot__value">{value}</div>
    </div>
  );
}
