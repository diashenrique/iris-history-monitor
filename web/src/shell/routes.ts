// The screens of contracts/ui-routes.md. "available" lists what this delivery ships (FR-023): screens
// of later deliveries keep their route (a shared link shows "not available yet") but stay out of the menu.
export interface ScreenDef {
  path: string;
  label: string;
  available: boolean;
}

export const SCREENS: ScreenDef[] = [
  { path: '/', label: 'nav.overview', available: true },
  { path: '/history', label: 'nav.history', available: false },
  { path: '/processes', label: 'nav.processes', available: false },
];
