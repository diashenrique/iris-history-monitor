// Fails when the committed build in ../src/web/historymonitor differs from a fresh build (research R12).
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readdirSync, readFileSync, rmSync, statSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, relative, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const committed = fileURLToPath(new URL('../../src/web/historymonitor', import.meta.url));
const fresh = mkdtempSync(join(tmpdir(), 'hm-build-'));

function list(dir) {
  const out = [];
  for (const name of readdirSync(dir)) {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) out.push(...list(path));
    else out.push(path);
  }
  return out;
}

try {
  const vite = fileURLToPath(new URL('../node_modules/vite/bin/vite.js', import.meta.url));
  execFileSync(process.execPath, [vite, 'build', '--outDir', fresh, '--emptyOutDir', '--logLevel', 'warn'], {
    stdio: 'inherit',
  });
  const a = new Map(list(committed).map((p) => [relative(committed, p).split(sep).join('/'), p]));
  const b = new Map(list(fresh).map((p) => [relative(fresh, p).split(sep).join('/'), p]));
  const problems = [];
  for (const [name, path] of b) {
    if (!a.has(name)) problems.push(`missing in committed build: ${name}`);
    else if (!readFileSync(path).equals(readFileSync(a.get(name)))) problems.push(`differs: ${name}`);
  }
  for (const name of a.keys()) if (!b.has(name)) problems.push(`not produced by a fresh build: ${name}`);
  if (problems.length) {
    console.error('The committed build is out of date. Run `npm run build` in web/ and commit src/web/historymonitor.');
    for (const p of problems) console.error(`  ${p}`);
    process.exit(1);
  }
  console.log(`committed build matches a fresh build (${b.size} files)`);
} finally {
  rmSync(fresh, { recursive: true, force: true });
}
