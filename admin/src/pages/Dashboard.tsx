import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { api } from "../lib/api";
import { StatusPill } from "../components/StatusPill";
import { IconDashboard, IconChat, IconCalendar, IconTag } from "../components/Icons";

interface RecentQuestion {
  id: string;
  userName: string | null;
  domain: string;
  question: string;
  status: string;
  createdAt: string;
  subscriptionPlanName: string;
}

interface Summary {
  totalUsers: number;
  usersWithBirthData: number;
  newUsersLast7Days: number;
  pendingQuestions: number;
  answeredQuestions: number;
  pendingAppointments: number;
  payingSubscribers: number;
  recentQuestions: RecentQuestion[];
}

export function Dashboard() {
  const [summary, setSummary] = useState<Summary | null>(null);

  useEffect(() => {
    api.get<Summary>("/admin/dashboard/summary").then(setSummary);
  }, []);

  if (!summary) {
    return (
      <div className="center-spin">
        <div className="spinner" />
      </div>
    );
  }

  return (
    <div>
      <div className="hero-banner">
        <div>
          <h1>Good to see you</h1>
          <p>A snapshot of what's moving in Traffic Jam right now — real charts, real questions, real people.</p>
        </div>
        <div className="hero-banner__stat">
          <div className="stat__label">Total Users</div>
          <div className="stat__value">{summary.totalUsers}</div>
          <div className="stat__hint" style={{ color: "var(--violet-200)" }}>
            +{summary.newUsersLast7Days} this week
          </div>
        </div>
      </div>

      <div className="dash-grid">
        <div>
          <div className="stat-grid">
            <div className="stat">
              <div className="stat__icon">
                <IconDashboard />
              </div>
              <div className="stat__label">Charts Cast</div>
              <div className="stat__value">{summary.usersWithBirthData}</div>
              <div className="stat__hint">have saved birth data</div>
            </div>
            <div className="stat">
              <div className="stat__icon stat__icon--gold">
                <IconChat />
              </div>
              <div className="stat__label">Pending Questions</div>
              <div className="stat__value stat__value--gold">{summary.pendingQuestions}</div>
              <div className="stat__hint">{summary.answeredQuestions} answered so far</div>
            </div>
            <div className="stat">
              <div className="stat__icon stat__icon--gold">
                <IconCalendar />
              </div>
              <div className="stat__label">Pending Appointments</div>
              <div className="stat__value stat__value--gold">{summary.pendingAppointments}</div>
              <div className="stat__hint">awaiting scheduling</div>
            </div>
            <div className="stat">
              <div className="stat__icon">
                <IconTag />
              </div>
              <div className="stat__label">Paying Subscribers</div>
              <div className="stat__value">{summary.payingSubscribers}</div>
              <div className="stat__hint">on a Saga+ plan</div>
            </div>
          </div>

          <div className="flex-between" style={{ marginBottom: 14 }}>
            <h2>Recent questions</h2>
            <Link to="/questions" className="muted" style={{ fontSize: 12.5, textDecoration: "none", fontWeight: 600 }}>
              View all →
            </Link>
          </div>
          <div className="table-card">
            {summary.recentQuestions.length === 0 ? (
              <div className="empty">No questions yet.</div>
            ) : (
              <div className="row-list">
                {summary.recentQuestions.map((q) => (
                  <Link key={q.id} to="/questions" className="row">
                    <div className="row__main">
                      <div className="row__title">{q.question}</div>
                      <div className="row__sub">
                        {q.userName ?? "Unnamed user"} · {q.domain}
                      </div>
                    </div>
                    <span
                      className="chip"
                      style={{ padding: "3px 11px", opacity: q.subscriptionPlanName === "Free" ? 0.55 : 1 }}
                    >
                      {q.subscriptionPlanName}
                    </span>
                    <StatusPill status={q.status} />
                  </Link>
                ))}
              </div>
            )}
          </div>
        </div>

        <div className="side-panel">
          <div className="side-card">
            <div className="eyebrow" style={{ marginBottom: 14 }}>
              Needs attention
            </div>
            <Link to="/questions" className="side-card__row">
              <span className="side-card__label">Pending questions</span>
              <span className="side-card__value">{summary.pendingQuestions}</span>
            </Link>
            <Link to="/appointments" className="side-card__row">
              <span className="side-card__label">Pending appointments</span>
              <span className="side-card__value">{summary.pendingAppointments}</span>
            </Link>
          </div>

          <div className="side-card">
            <div className="eyebrow eyebrow--gold" style={{ marginBottom: 14 }}>
              This week
            </div>
            <div className="side-card__row">
              <span className="side-card__label">New signups</span>
              <span className="side-card__value">{summary.newUsersLast7Days}</span>
            </div>
            <div className="side-card__row">
              <span className="side-card__label">Questions answered</span>
              <span className="side-card__value">{summary.answeredQuestions}</span>
            </div>
          </div>

          <div className="side-card" style={{ background: "var(--gradient-hero)", border: "1px solid var(--gold-border)" }}>
            <div className="eyebrow eyebrow--gold" style={{ marginBottom: 8 }}>
              Quick links
            </div>
            <p className="muted" style={{ fontSize: 12.5, margin: "0 0 14px", lineHeight: 1.6 }}>
              Manage what users see without a redeploy.
            </p>
            <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
              <Link to="/remedies" className="btn btn--ghost btn--sm" style={{ justifyContent: "center" }}>
                Edit remedies
              </Link>
              <Link to="/plans" className="btn btn--ghost btn--sm" style={{ justifyContent: "center" }}>
                Edit pricing
              </Link>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
