import { ApiError, createClient, loginUrl } from '../../src/api/client';

function respond(status: number, body?: unknown) {
  return vi.fn(async (_url: string, _init?: RequestInit) =>
    new Response(body === undefined ? '' : JSON.stringify(body), { status }),
  );
}

describe('API client', () => {
  it('reads from ./api/v1 with the session cookie', async () => {
    const fetch = respond(200, { interfaceEnabled: true });
    const api = createClient({ fetch: fetch as unknown as typeof globalThis.fetch });
    await expect(api.settings()).resolves.toEqual({ interfaceEnabled: true });
    expect(fetch.mock.calls[0]?.[0]).toBe('./api/v1/settings');
    expect(fetch.mock.calls[0]?.[1]?.credentials).toBe('same-origin');
  });

  it('encodes parameters and leaves out empty ones', async () => {
    const fetch = respond(200, { items: [], total: 0, page: 1, pageSize: 50 });
    const api = createClient({ fetch: fetch as unknown as typeof globalThis.fetch });
    await api.processes({ namespace: '%SYS', q: '', page: 2 });
    expect(fetch.mock.calls[0]?.[0]).toBe('./api/v1/processes?namespace=%25SYS&page=2');
  });

  it('on 401 calls the sign-in handler and fails as unauthorized', async () => {
    const onUnauthorized = vi.fn();
    const api = createClient({ fetch: respond(401) as unknown as typeof fetch, onUnauthorized });
    await expect(api.overview()).rejects.toMatchObject({ kind: 'unauthorized', status: 401 });
    expect(onUnauthorized).toHaveBeenCalledOnce();
  });

  it('on 403 fails as forbidden with the problem title', async () => {
    const problem = { type: '/problems/forbidden', title: 'Forbidden', status: 403, detail: 'x' };
    const api = createClient({ fetch: respond(403, problem) as unknown as typeof fetch });
    const err = (await api.overview().catch((e) => e)) as ApiError;
    expect(err.kind).toBe('forbidden');
    expect(err.message).toBe('Forbidden');
  });

  it('shows the problem title, never internal text, for other errors', async () => {
    const problem = { type: '/problems/internal-error', title: 'Internal Server Error', status: 500, detail: 'An internal error occurred.' };
    const api = createClient({ fetch: respond(500, problem) as unknown as typeof fetch });
    const err = (await api.overview().catch((e) => e)) as ApiError;
    expect(err.kind).toBe('problem');
    expect(err.message).toBe('Internal Server Error');
  });

  it('reports a network failure', async () => {
    const api = createClient({ fetch: (async () => { throw new TypeError('Failed to fetch'); }) as unknown as typeof fetch });
    await expect(api.overview()).rejects.toMatchObject({ kind: 'network' });
  });

  it('builds the login address with the current route (research R5)', () => {
    expect(loginUrl('#/history?metric=license')).toBe(
      './diashenrique.historymonitor.web.Login.cls?return=%23%2Fhistory%3Fmetric%3Dlicense',
    );
    expect(loginUrl('')).toBe('./diashenrique.historymonitor.web.Login.cls?return=%23%2F');
  });
});
