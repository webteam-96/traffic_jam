import { NavLink, Outlet } from "react-router-dom";
import { useEffect, useState } from "react";
import { useAuth } from "../lib/auth";
import { api } from "../lib/api";
import { IconDashboard, IconChat, IconCalendar, IconUsers, IconLeaf, IconTag } from "./Icons";

interface Counts {
  pendingQuestions: number;
  pendingAppointments: number;
}

const NAV = [
  { to: "/", label: "Dashboard", icon: IconDashboard, end: true },
  { to: "/questions", label: "Ask Jay", icon: IconChat, countKey: "pendingQuestions" as const },
  { to: "/appointments", label: "Appointments", icon: IconCalendar, countKey: "pendingAppointments" as const },
  { to: "/users", label: "Users", icon: IconUsers },
  { to: "/remedies", label: "Remedies", icon: IconLeaf },
  { to: "/plans", label: "Pricing", icon: IconTag },
];

export function Layout() {
  const { admin, logout } = useAuth();
  const [counts, setCounts] = useState<Counts | null>(null);

  useEffect(() => {
    let cancelled = false;
    const load = () =>
      api
        .get<Counts>("/admin/dashboard/summary")
        .then((s) => !cancelled && setCounts(s))
        .catch(() => {});
    load();
    const interval = setInterval(load, 60_000);
    return () => {
      cancelled = true;
      clearInterval(interval);
    };
  }, []);

  const initial = admin?.name?.trim()?.[0]?.toUpperCase() ?? "?";

  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="brand">
          <div className="brand__mark">
            <svg width="14" height="14" viewBox="0 0 20 20">
              <circle cx="10" cy="4.5" r="2.6" fill="#4ADE80" />
              <circle cx="10" cy="10" r="2.6" fill="#FFC107" />
              <circle cx="10" cy="15.5" r="2.6" fill="#FF6B6B" />
            </svg>
          </div>
          <div>
            <div className="brand__word">Traffic Jam</div>
            <div className="brand__sub">Control Room</div>
          </div>
        </div>

        <nav className="nav">
          {NAV.map(({ to, label, icon: Icon, end, countKey }) => {
            const count = countKey ? counts?.[countKey] : undefined;
            return (
              <NavLink key={to} to={to} end={end} className={({ isActive }) => `nav__link${isActive ? " active" : ""}`}>
                <Icon />
                <span>{label}</span>
                {!!count && <span className="nav__badge">{count}</span>}
              </NavLink>
            );
          })}
        </nav>

        <div className="sidebar__footer">
          <div className="admin-chip">
            <div className="admin-chip__avatar">{initial}</div>
            <div>
              <div className="admin-chip__name">{admin?.name}</div>
              <div className="admin-chip__email">{admin?.email}</div>
            </div>
          </div>
          <button className="signout" onClick={logout}>
            Sign out
          </button>
        </div>
      </aside>

      <main className="main">
        <Outlet />
      </main>
    </div>
  );
}
