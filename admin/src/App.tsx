import { HashRouter, Navigate, Route, Routes } from "react-router-dom";
import { AuthProvider, useAuth } from "./lib/auth";
import { ToastProvider } from "./lib/toast";
import { Layout } from "./components/Layout";
import { Login } from "./pages/Login";
import { Dashboard } from "./pages/Dashboard";
import { Questions } from "./pages/Questions";
import { Appointments } from "./pages/Appointments";
import { Users } from "./pages/Users";
import { Remedies } from "./pages/Remedies";
import { Plans } from "./pages/Plans";

function Gate({ children }: { children: React.ReactNode }) {
  const { admin, loading } = useAuth();

  if (loading) {
    return (
      <div className="center-spin" style={{ minHeight: "100vh" }}>
        <div className="spinner" />
      </div>
    );
  }

  return admin ? <>{children}</> : <Navigate to="/login" replace />;
}

function AppRoutes() {
  const { admin } = useAuth();

  return (
    <Routes>
      <Route path="/login" element={admin ? <Navigate to="/" replace /> : <Login />} />
      <Route
        path="/"
        element={
          <Gate>
            <Layout />
          </Gate>
        }
      >
        <Route index element={<Dashboard />} />
        <Route path="questions" element={<Questions />} />
        <Route path="appointments" element={<Appointments />} />
        <Route path="users" element={<Users />} />
        <Route path="remedies" element={<Remedies />} />
        <Route path="plans" element={<Plans />} />
      </Route>
    </Routes>
  );
}

export default function App() {
  return (
    // HashRouter, not BrowserRouter: routes live after a "#" (e.g.
    // /#/users) so the browser never sends a real request for them to the
    // server on reload/direct-link — only ever requests index.html, which
    // always exists. BrowserRouter needs the web server configured to
    // fall back to index.html for unknown paths (a standard SPA rewrite
    // rule); without that, reloading anything but "/" 404s at the server
    // before React Router ever gets a chance to handle it.
    <HashRouter>
      <AuthProvider>
        <ToastProvider>
          <AppRoutes />
        </ToastProvider>
      </AuthProvider>
    </HashRouter>
  );
}
