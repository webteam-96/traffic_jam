import { createContext, useContext, useEffect, useState, type ReactNode } from "react";
import { api, clearToken, getToken, onUnauthorized, setToken } from "./api";

interface AdminIdentity {
  id: string;
  name: string;
  email: string;
}

interface AuthContextValue {
  admin: AdminIdentity | null;
  loading: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [admin, setAdmin] = useState<AdminIdentity | null>(null);
  const [loading, setLoading] = useState(true);

  const logout = () => {
    clearToken();
    setAdmin(null);
  };

  useEffect(() => {
    onUnauthorized.handler = logout;
    return () => {
      onUnauthorized.handler = null;
    };
  }, []);

  useEffect(() => {
    if (!getToken()) {
      setLoading(false);
      return;
    }
    api
      .get<AdminIdentity>("/admin/auth/me")
      .then(setAdmin)
      .catch(() => clearToken())
      .finally(() => setLoading(false));
  }, []);

  const login = async (email: string, password: string) => {
    const response = await api.post<{ accessToken: string; name: string; email: string }>(
      "/admin/auth/login",
      { email, password },
    );
    setToken(response.accessToken);
    const me = await api.get<AdminIdentity>("/admin/auth/me");
    setAdmin(me);
  };

  return <AuthContext.Provider value={{ admin, loading, login, logout }}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}
