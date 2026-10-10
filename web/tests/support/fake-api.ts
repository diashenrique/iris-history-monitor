import { QueryClient } from '@tanstack/react-query';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { ApiError, type ApiClient } from '../../src/api/client';

/** A fixture from tests/fixtures (each one is checked against the API contract). */
export function fixture<T>(name: string): T {
  return JSON.parse(readFileSync(resolve(process.cwd(), 'tests/fixtures', `${name}.json`), 'utf8')) as T;
}

export const forbidden = () => new ApiError('forbidden', 403, 'Forbidden', fixture('problem-forbidden'));
export const networkDown = () => new ApiError('network', 0, 'network');

/** An API client whose calls are mocks; each starts with a sensible default. */
export function fakeApi(overrides: Partial<Record<keyof ApiClient, ReturnType<typeof vi.fn>>> = {}) {
  const api = {
    settings: vi.fn(async () => fixture('settings-on')),
    overview: vi.fn(async () => fixture('overview')),
    history: vi.fn(async () => fixture('history-database')),
    processes: vi.fn(async () => fixture('processes-page1')),
    ...overrides,
  };
  return api as unknown as ApiClient & typeof api;
}

export function testQueryClient() {
  return new QueryClient({ defaultOptions: { queries: { retry: false, gcTime: Infinity } } });
}
