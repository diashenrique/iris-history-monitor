// The screens of contracts/ui-routes.md, in menu order. "available" let screens ship one at a time
// (FR-023); all three are delivered now.
export interface ScreenDef {
  path: string;
  label: string;
  available: boolean;
}

export const SCREENS: ScreenDef[] = [
  { path: '/', label: 'nav.overview', available: true },
  { path: '/history', label: 'nav.history', available: true },
  { path: '/processes', label: 'nav.processes', available: true },
];
