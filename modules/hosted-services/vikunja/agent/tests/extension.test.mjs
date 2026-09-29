import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';

const sdk = process.env.PI_SDK_ROOT;
assert.ok(sdk, 'PI_SDK_ROOT is required');
const require = createRequire(resolve(sdk, 'package.json'));
const { createJiti } = require('jiti');
const jiti = createJiti(import.meta.url, { alias: {
  'typebox': resolve(sdk, 'node_modules/typebox/build/index.mjs'),
  '@earendil-works/pi-ai': resolve(sdk, 'node_modules/@earendil-works/pi-ai/dist/index.js'),
}, moduleCache: false });
const { registerVikunja } = await jiti.import(resolve('index.ts'));
const { Value } = await import(pathToFileURL(resolve(sdk, 'node_modules/typebox/build/value/index.mjs')));

test('registers on-demand tools only: no commands, hooks, model calls or confirmation gates', () => {
  const tools = [];
  registerVikunja({ registerTool: tool => tools.push(tool) });
  assert.equal(tools.length, 14);
  assert.equal(new Set(tools.map(t => t.name)).size, 14);
  const deletion = tools.find(t => t.name === 'vikunja_delete');
  assert.equal(Value.Check(deletion.parameters, { resource: 'projects', id: 1 }), true);
  assert.equal(Value.Check(deletion.parameters, { resource: 'projects', id: 1, confirm: true }), false);
  for (const tool of tools) {
    const encoded = JSON.stringify(tool.parameters);
    assert.doesNotMatch(encoded, /"(tokenFile|baseUrl|profile|confirmation)"\s*:/);
  }
});
test('typed edits reject unknown fields and malformed dates, retain false/zero/empty content', () => {
  const tools = [];
  registerVikunja({ registerTool: tool => tools.push(tool) }, 'full');
  const schema = tools.find(t => t.name === 'vikunja_task_update').parameters;
  const base = { id: 1, revision: 'a'.repeat(64) };
  assert.equal(Value.Check(schema, { ...base, changes: { done: false, priority: 0, description: '' } }), true);
  assert.equal(Value.Check(schema, { ...base, changes: { assignees: [123] } }), false);
  assert.equal(Value.Check(schema, { ...base, changes: { due_date: 'tomorrow' } }), false);
  assert.equal(Value.Check(schema, { ...base, changes: { due_date: '2026-10-01T10:00:00+13:00' } }), true);
});
