import Ajv from 'ajv';
import addFormats from 'ajv-formats';
import { readdirSync, readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';

// Every API fixture the interface tests use must match the API contract, so a mocked response cannot
// drift from what the server really sends (research R13). The contract is the generated openapi.json.
// Vitest runs from web/ (jsdom gives import.meta.url an http scheme, so paths start from the project).
const contractPath = resolve(process.cwd(), '../specs/001-api-v1/contracts/openapi.json');
const fixturesDir = resolve(process.cwd(), 'tests/fixtures');
const contract = JSON.parse(readFileSync(contractPath, 'utf8'));

// OpenAPI 3.0 "nullable" is not JSON Schema: turn it into an explicit null alternative. "example" is
// documentation only and is ignored (strict: false).
function toJsonSchema(node: unknown): unknown {
  if (Array.isArray(node)) return node.map(toJsonSchema);
  if (!node || typeof node !== 'object') return node;
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(node)) if (k !== 'nullable') out[k] = toJsonSchema(v);
  if ((node as { nullable?: boolean }).nullable) return { anyOf: [{ type: 'null' }, out] };
  return out;
}

const ajv = new Ajv({ strict: false, allErrors: true });
addFormats(ajv);
ajv.addSchema({ $id: 'openapi.json', components: toJsonSchema(contract.components) });

/** Which schema each fixture must satisfy, by file name prefix. */
const schemaFor: [prefix: string, schema: string][] = [
  ['settings', 'Settings'],
  ['overview', 'OverviewSnapshot'],
  ['history', 'HistorySeries'],
  ['processes', 'ProcessPage'],
  ['problem', 'Problem'],
];

const fixtures = readdirSync(fixturesDir).filter((f) => f.endsWith('.json'));

describe('API fixtures match the contract', () => {
  it('has fixtures', () => expect(fixtures.length).toBeGreaterThan(5));

  it.each(fixtures)('%s', (file) => {
    const entry = schemaFor.find(([prefix]) => file.startsWith(prefix));
    expect(entry, `no schema for ${file}`).toBeDefined();
    const validate = ajv.getSchema(`openapi.json#/components/schemas/${entry![1]}`)!;
    const data = JSON.parse(readFileSync(join(fixturesDir, file), 'utf8'));
    const ok = validate(data);
    expect(ok, JSON.stringify(validate.errors)).toBe(true);
  });

  it('rejects a response that drifts from the contract', () => {
    const validate = ajv.getSchema('openapi.json#/components/schemas/Metric')!;
    expect(validate({ name: 'x', value: 1, unit: 'count', status: 'fine' })).toBe(false);
    expect(validate({ name: 'x', value: 1, status: 'ok' })).toBe(false);
  });
});
