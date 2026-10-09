import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';
import { fileURLToPath } from 'node:url';

// The build is committed to src/web/historymonitor and installed by IPM as the static web
// application under /historymonitor/ (research R12). base './' keeps every asset path relative.
export const outDir = fileURLToPath(new URL('../src/web/historymonitor', import.meta.url));

export default defineConfig({
  base: './',
  plugins: [react(), tailwindcss()],
  build: {
    outDir,
    emptyOutDir: true,
    sourcemap: false,
    assetsDir: 'assets',
    // The chart chunk (ECharts) is large but loads only with the history screen; the first screen has
    // its own budget, enforced by scripts/check-size.mjs.
    chunkSizeWarningLimit: 700,
  },
  server: {
    // During development, API calls go to a local IRIS (set HM_IRIS, default localhost:52773).
    proxy: { '/historymonitor/api': process.env.HM_IRIS ?? 'http://localhost:52773' },
  },
});
