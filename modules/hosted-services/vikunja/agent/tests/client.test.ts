import { test } from 'node:test';
import assert from 'node:assert/strict';
import { VikunjaClient, validateConfig, revision, toolResult } from '../client.ts';

const config = { baseUrl: 'https://todo.example.test', tokenFile: '/run/mock-token' };
function fixture(responses: (Response | Error)[], override = {}) {
  const calls: { url: URL; init: RequestInit }[] = [];
  const client = new VikunjaClient({ ...config, ...override }, (async (url, init) => {
    calls.push({ url: new URL(String(url)), init: init! });
    const item = responses.shift();
    if (item instanceof Error) throw item;
    assert.ok(item, 'Unexpected request');
    return item;
  }) as typeof fetch, async () => 'fake-test-credential');
  return { client, calls };
}
const json = (data: unknown, headers = {}) => new Response(JSON.stringify(data), { headers });

test('only credential-free HTTPS origins and absolute token files', () => {
  for (const baseUrl of ['http://todo.test', 'https://u:p@todo.test', 'https://todo.test/api', 'https://todo.test/?q=x', 'https://todo.test/#x']) {
    assert.throws(() => validateConfig({ ...config, baseUrl }));
  }
  assert.throws(() => validateConfig({ ...config, tokenFile: 'token' }));
  assert.throws(() => validateConfig({ ...config, defaultProjectId: -1 }));
});
test('list uses v2 pagination, search q, Markdown and default project', async () => {
  const body = { items: [{ id: 4 }], total: 21, page: 2, per_page: 20, total_pages: 2 };
  const { client, calls } = fixture([json(body)], { defaultProjectId: 7 });
  assert.deepEqual(await client.list('tasks', { page: 2, query: 'a & b', filter: 'done = false', timezone: 'Pacific/Auckland' }), body);
  assert.equal(calls[0].url.pathname, '/api/v2/projects/7/tasks');
  assert.equal(calls[0].url.searchParams.get('q'), 'a & b');
  assert.equal(calls[0].url.searchParams.get('per_page'), '20');
  assert.equal(calls[0].url.searchParams.get('format'), 'markdown');
  assert.equal(calls[0].init.redirect, 'error');
});
test('unbound and explicit project listing routes', async () => {
  const { client, calls } = fixture([json({}), json({})]);
  await client.list('tasks'); await client.list('tasks', { projectId: 9 });
  assert.equal(calls[0].url.pathname, '/api/v2/tasks');
  assert.equal(calls[1].url.pathname, '/api/v2/projects/9/tasks');
});
test('create preserves zero/false fields and requires destination', async () => {
  const { client, calls } = fixture([json({ id: 1 })]);
  await assert.rejects(client.create('tasks', { title: 'x' }), /positive numeric ID/);
  await client.create('tasks', { title: 'x', done: false, priority: 0 }, { projectId: 8 });
  assert.deepEqual(JSON.parse(calls[0].init.body as string), { title: 'x', done: false, priority: 0 });
  assert.equal(calls[0].init.method, 'POST');
});
test('read revision, preflight and partial PATCH; forwards ETag when available', async () => {
  const data = { id: 1, title: 'Keep', description: 'Keep too', done: false };
  const { client, calls } = fixture([json(data), json(data, { etag: '"etag"' }), json({ ...data, done: true })]);
  const read = await client.get('tasks', 1);
  await client.update('tasks', 1, read.revision, { done: true });
  assert.equal(calls[2].init.method, 'PATCH');
  assert.equal(calls[2].url.searchParams.has('format'), false);
  assert.equal(new Headers(calls[2].init.headers).get('X-Vikunja-Format'), 'html');
  assert.equal(new Headers(calls[2].init.headers).get('If-Match'), '"etag"');
  assert.equal(new Headers(calls[2].init.headers).get('Content-Type'), 'application/merge-patch+json');
  assert.deepEqual(JSON.parse(calls[2].init.body as string), { done: true });
});
test('rich-text patches use the Markdown header, not the stripped query', async () => {
  const data = { id: 1, description: 'old' };
  const { client, calls } = fixture([json(data), json({})]);
  await client.update('tasks', 1, revision(data), { description: '**new**' });
  assert.equal(new Headers(calls[1].init.headers).get('X-Vikunja-Format'), 'markdown');
  assert.equal(calls[1].url.searchParams.has('format'), false);
});
test('project update supports lack of ETag but retains stale precheck', async () => {
  const data = { id: 1, title: 'p' };
  const { client, calls } = fixture([json(data), json({})]);
  await client.update('projects', 1, revision(data), { parent_project_id: 0 });
  assert.equal(new Headers(calls[1].init.headers).has('If-Match'), false);
});
test('stale, empty and invalid updates never write', async () => {
  const { client, calls } = fixture([json({ title: 'changed' })]);
  await assert.rejects(client.update('tasks', 1, revision({}), { title: 'x' }), /changed since read/);
  await assert.rejects(client.update('tasks', 1, revision({}), {}));
  await assert.rejects(client.update('tasks', 1, 'invalid', { title: 'x' }));
  assert.equal(calls.length, 1);
});
test('deletes are immediate, including projects and comments, with no confirm protocol', async () => {
  const { client, calls } = fixture([new Response(null, { status: 204 }), json(null)]);
  assert.deepEqual(await client.delete('projects', 5), { deleted: true, resource: 'projects', id: 5 });
  await client.delete('comments', 9, 2);
  assert.equal(calls[0].init.method, 'DELETE');
  assert.equal(calls[1].url.pathname, '/api/v2/tasks/2/comments/9');
});
test('relations and label membership use exact nested routes', async () => {
  const { client, calls } = fixture(Array.from({ length: 4 }, () => json({})));
  await client.relation(1, 2, 'blocking', false);
  await client.relation(1, 2, 'blocking', true);
  await client.taskLabel(1, 3, false);
  await client.taskLabel(1, 3, true);
  assert.deepEqual(JSON.parse(calls[0].init.body as string), { other_task_id: 2, relation_kind: 'blocking' });
  assert.equal(calls[1].url.pathname, '/api/v2/tasks/1/relations/blocking/2');
  assert.deepEqual(JSON.parse(calls[2].init.body as string), { label_id: 3 });
  assert.equal(calls[3].url.pathname, '/api/v2/tasks/1/labels/3');
});
test('invalid IDs, self relations, missing parent, and non-task filters fail before transport', async () => {
  const { client, calls } = fixture([]);
  await assert.rejects(client.delete('tasks', NaN));
  await assert.rejects(client.get('comments', 1));
  await assert.rejects(client.relation(1, 1, 'subtask', false));
  await assert.rejects(client.list('projects', { filter: 'done = false' }));
  assert.equal(calls.length, 0);
});
test('errors redact server body and transport errors; never retry writes', async () => {
  for (const response of [new Response('fake-test-credential', { status: 403 }), new Error('fake-test-credential')]) {
    const { client, calls } = fixture([response]);
    await assert.rejects(client.create('projects', { title: 'p' }), error => !String(error).includes('fake-test-credential'));
    assert.equal(calls.length, 1);
  }
});
test('conflict statuses are explicit and never retried', async () => {
  const { client, calls } = fixture([new Response('', { status: 412 })]);
  await assert.rejects(client.delete('tasks', 1), /conflict/);
  assert.equal(calls.length, 1);
});
test('success response token echoes are redacted', async () => {
  const { client } = fixture([json({ message: 'fake-test-credential' })]);
  assert.doesNotMatch(JSON.stringify(await client.status()), /fake-test-credential/);
});
test('response stream is bounded and oversized reads issue no revision', async () => {
  const { client } = fixture([json({ text: 'a'.repeat(1100000) }), json({ text: 'a'.repeat(50000) })]);
  await assert.rejects(client.get('tasks', 1), /1 MiB/);
  await assert.rejects(client.get('tasks', 1), /output limit/);
  assert.equal(toolResult({ text: 'a'.repeat(50000) }).details.truncated, true);
});
test('token is reread for rotation and is never in URL or body', async () => {
  let current = 'first-fake-token';
  const seen: string[] = [];
  const client = new VikunjaClient(config, (async (url, init) => {
    assert.doesNotMatch(String(url), /fake-token/);
    seen.push(new Headers(init?.headers).get('Authorization')!);
    return json({ message: 'ok' });
  }) as typeof fetch, async () => current);
  await client.status(); current = 'second-fake-token'; await client.status();
  assert.deepEqual(seen, ['Bearer first-fake-token', 'Bearer second-fake-token']);
});
test('missing and malformed token errors omit file content', async () => {
  const fetcher = (async () => { throw Error('must not call'); }) as typeof fetch;
  for (const token of ['', 'Bearer fake', 'first\nsecond']) {
    const client = new VikunjaClient(config, fetcher, async () => token);
    await assert.rejects(client.status(), /raw single-line/);
  }
});
test('abort is propagated into the transport signal', async () => {
  const abort = new AbortController(); abort.abort();
  const client = new VikunjaClient(config, (async (_url, init) => {
    assert.equal(init?.signal?.aborted, true); throw Error('aborted');
  }) as typeof fetch, async () => 'fake-token');
  await assert.rejects(client.status(abort.signal), /cancelled/);
});
