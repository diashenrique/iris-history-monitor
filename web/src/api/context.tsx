import { createContext, useContext, type ReactNode } from 'react';
import { createClient, type ApiClient } from './client';

const ApiContext = createContext<ApiClient | null>(null);

export function ApiProvider({ client, children }: { client?: ApiClient; children: ReactNode }) {
  return <ApiContext.Provider value={client ?? createClient()}>{children}</ApiContext.Provider>;
}

export function useApi(): ApiClient {
  const api = useContext(ApiContext);
  if (!api) throw new Error('useApi outside ApiProvider');
  return api;
}
