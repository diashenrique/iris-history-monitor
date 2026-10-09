import type { HistorySeries, OverviewSnapshot, Problem, ProcessPage, Settings } from './types';

// The only source of data of the interface (FR-001): the API under the same prefix, ./api/v1.
export const API_BASE = './api/v1';

/** Where the interface signs in (research R3, R5): IRIS shows its login form, then comes back. */
export const LOGIN_PAGE = './diashenrique.historymonitor.web.Login.cls';

export type ApiErrorKind = 'unauthorized' | 'forbidden' | 'problem' | 'network';

/** An API failure. The message is safe to show: a problem title from the API, never internal text. */
export class ApiError extends Error {
  readonly kind: ApiErrorKind;
  readonly status: number;
  readonly problem?: Problem;

  constructor(kind: ApiErrorKind, status: number, message: string, problem?: Problem) {
    super(message);
    this.name = 'ApiError';
    this.kind = kind;
    this.status = status;
    this.problem = problem;
  }
}

export interface ClientOptions {
  fetch?: typeof fetch;
  /** Called on 401; by default sends the browser to the login page with the current route. */
  onUnauthorized?: () => void;
}

export function loginUrl(hash: string): string {
  return `${LOGIN_PAGE}?return=${encodeURIComponent(hash || '#/')}`;
}

export function goToLogin(): void {
  window.location.assign(loginUrl(window.location.hash));
}

function isProblem(body: unknown): body is Problem {
  return !!body && typeof body === 'object' && 'title' in body && 'status' in body;
}

export function createClient(options: ClientOptions = {}) {
  const doFetch = options.fetch ?? ((...args: Parameters<typeof fetch>) => fetch(...args));
  const onUnauthorized = options.onUnauthorized ?? goToLogin;

  async function get<T>(path: string, params?: Record<string, string | number | undefined>): Promise<T> {
    const query = new URLSearchParams();
    for (const [k, v] of Object.entries(params ?? {})) if (v !== undefined && v !== '') query.append(k, String(v));
    const url = `${API_BASE}${path}${query.size ? `?${query}` : ''}`;
    let response: Response;
    try {
      response = await doFetch(url, { credentials: 'same-origin', headers: { Accept: 'application/json' } });
    } catch {
      throw new ApiError('network', 0, 'network');
    }
    if (response.status === 401) {
      onUnauthorized();
      throw new ApiError('unauthorized', 401, 'unauthorized');
    }
    let body: unknown = null;
    try {
      body = await response.json();
    } catch {
      body = null;
    }
    if (response.status === 403) {
      throw new ApiError('forbidden', 403, isProblem(body) ? body.title : 'Forbidden', isProblem(body) ? body : undefined);
    }
    if (!response.ok) {
      const title = isProblem(body) ? body.title : `HTTP ${response.status}`;
      throw new ApiError('problem', response.status, title, isProblem(body) ? body : undefined);
    }
    return body as T;
  }

  return {
    settings: () => get<Settings>('/settings'),
    overview: () => get<OverviewSnapshot>('/overview'),
    history: (metric: string, params: Record<string, string | number | undefined>) =>
      get<HistorySeries>(`/history/${encodeURIComponent(metric)}`, params),
    processes: (params: Record<string, string | number | undefined>) => get<ProcessPage>('/processes', params),
  };
}

export type ApiClient = ReturnType<typeof createClient>;
