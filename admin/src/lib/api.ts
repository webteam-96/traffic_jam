// Backend base URL — sourced entirely from VITE_API_BASE_URL, which Vite
// loads from .env.development or .env.production depending on `npm run dev`
// vs `npm run build` (see those files, and .env.example for the override
// convention). Not hardcoded here so there's exactly one place per
// environment to update if the backend's domain or proxy path ever changes.
const BASE_URL = import.meta.env.VITE_API_BASE_URL;
if (!BASE_URL) {
  throw new Error(
    "VITE_API_BASE_URL is not set — see admin/.env.development, admin/.env.production, or admin/.env.example.",
  );
}

const TOKEN_KEY = "tj_admin_token";

export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY);
}

export function setToken(token: string) {
  localStorage.setItem(TOKEN_KEY, token);
}

export function clearToken() {
  localStorage.removeItem(TOKEN_KEY);
}

export class ApiError extends Error {
  status: number;
  code?: string;
  constructor(status: number, message: string, code?: string) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

/** Fired on any 401 so the app shell can drop back to the login screen. */
export const onUnauthorized = { handler: null as (() => void) | null };

async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  const token = getToken();
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    ...(options.headers as Record<string, string>),
  };
  if (token) headers.Authorization = `Bearer ${token}`;

  const response = await fetch(`${BASE_URL}${path}`, { ...options, headers });

  if (!response.ok) {
    let message = `Request failed (${response.status})`;
    let code: string | undefined;
    try {
      const body = await response.json();
      message = body?.error?.message ?? message;
      code = body?.error?.code;
    } catch {
      // non-JSON error body — keep the generic message
    }

    // A 401 only means "your session expired" when a token was actually
    // sent and rejected. A 401 on an unauthenticated request (e.g. a wrong
    // password on /admin/auth/login itself) is just that call failing —
    // there's no session to drop, and the real server message (e.g.
    // "Incorrect email or password.") is what the user should see.
    if (response.status === 401 && token) {
      clearToken();
      onUnauthorized.handler?.();
      message = "Session expired — please sign in again.";
    }

    throw new ApiError(response.status, message, code);
  }

  if (response.status === 204) return undefined as T;
  const text = await response.text();
  return text ? (JSON.parse(text) as T) : (undefined as T);
}

export const api = {
  get: <T>(path: string) => request<T>(path),
  post: <T>(path: string, body?: unknown) =>
    request<T>(path, { method: "POST", body: body !== undefined ? JSON.stringify(body) : undefined }),
  put: <T>(path: string, body?: unknown) =>
    request<T>(path, { method: "PUT", body: JSON.stringify(body) }),
  patch: <T>(path: string, body?: unknown) =>
    request<T>(path, { method: "PATCH", body: JSON.stringify(body) }),
  delete: <T>(path: string) => request<T>(path, { method: "DELETE" }),
};
