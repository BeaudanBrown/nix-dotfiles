import { readFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { homedir } from 'node:os';
import { isAbsolute, join } from 'node:path';

export type Resource = 'projects' | 'tasks' | 'labels' | 'comments';
export type Config = { baseUrl: string; tokenFile: string; defaultProjectId?: number };
type Fields = Record<string, unknown>;
type Query = Record<string, string | number | boolean | undefined>;
export const relations = ['subtask', 'parenttask', 'related', 'duplicateof', 'duplicates', 'blocking', 'blocked', 'precedes', 'follows', 'copiedfrom', 'copiedto'] as const;
const MAX_RESPONSE = 1024 * 1024;
export const MAX_OUTPUT = 48000;
class ClientError extends Error {}

export function id(value: unknown): number {
  if (!Number.isSafeInteger(value) || Number(value) <= 0) throw new ClientError('Expected a positive numeric ID returned by Vikunja.');
  return value as number;
}
export function validateConfig(raw: Config): Config {
  const url = new URL(raw.baseUrl);
  if (url.protocol !== 'https:' || url.username || url.password || url.search || url.hash || url.pathname !== '/') {
    throw new ClientError('Vikunja requires a fixed HTTPS origin without credentials, path or query.');
  }
  if (typeof raw.tokenFile !== 'string' || !isAbsolute(raw.tokenFile)) throw new ClientError('Token file must be an absolute runtime path.');
  return { baseUrl: url.origin, tokenFile: raw.tokenFile,
    ...(raw.defaultProjectId === undefined ? {} : { defaultProjectId: id(raw.defaultProjectId) }) };
}
export async function loadConfig(profile: 'default' | 'full'): Promise<Config> {
  try {
    const root = process.env.XDG_CONFIG_HOME || join(homedir(), '.config');
    return validateConfig(JSON.parse(await readFile(join(root, 'vikunja-agent', `${profile}.json`), 'utf8')));
  } catch { throw new ClientError('Vikunja configuration unavailable or invalid. Provision the selected host profile.'); }
}
export function revision(data: unknown): string {
  return createHash('sha256').update(JSON.stringify(data)).digest('hex');
}
function resourcePath(resource: Resource, resourceId?: number, taskId?: number): string {
  if (!['projects', 'tasks', 'labels', 'comments'].includes(resource)) throw new ClientError('Unknown resource.');
  const base = resource === 'comments' ? `/tasks/${id(taskId)}/comments` : `/${resource}`;
  return resourceId === undefined ? base : `${base}/${id(resourceId)}`;
}

/** No token or profile can be chosen by a tool call. Server account ACLs own access. */
export class VikunjaClient {
  readonly config: Config;
  private fetcher: typeof fetch;
  private readToken: () => Promise<string>;
  constructor(config: Config, fetcher: typeof fetch = fetch,
    readToken: () => Promise<string> = () => readFile(config.tokenFile, 'utf8')) {
    this.config = validateConfig(config);
    this.fetcher = fetcher;
    this.readToken = readToken;
  }
  async request(method: string, path: string, body?: Fields, query: Query = {}, signal?: AbortSignal,
    etag?: string): Promise<{ data: unknown; etag: string | null }> {
    // Paths are constructed exclusively by the methods below, never accepted from tools.
    if (!/^\/[a-z0-9/-]+$/.test(path)) throw new ClientError('Invalid API path.');
    const url = new URL(`/api/v2${path}`, this.config.baseUrl);
    // AutoPatch strips the query. Only round-trip Markdown when rich text was
    // actually edited; otherwise its internal GET/PUT must preserve stored HTML.
    if (method !== 'PATCH') url.searchParams.set('format', 'markdown');
    for (const [key, value] of Object.entries(query)) if (value !== undefined) url.searchParams.set(key, String(value));
    let token: string;
    try { token = (await this.readToken()).trim(); }
    catch { throw new ClientError('Vikunja token file unavailable. Populate the selected SOPS secret.'); }
    if (!token || /\s/.test(token) || token.length > 8192) throw new ClientError('Vikunja token must be a raw single-line API token.');
    const headers: Record<string, string> = { Authorization: `Bearer ${token}`, Accept: 'application/json' };
    if (body) headers['Content-Type'] = method === 'PATCH' ? 'application/merge-patch+json' : 'application/json';
    if (method === 'PATCH') headers['X-Vikunja-Format'] = body && ('description' in body || 'comment' in body) ? 'markdown' : 'html';
    if (etag) headers['If-Match'] = etag;
    try {
      const response = await this.fetcher(url, { method, headers, redirect: 'error',
        body: body ? JSON.stringify(body) : undefined,
        signal: AbortSignal.any([AbortSignal.timeout(30000), ...(signal ? [signal] : [])]) });
      if (!response.ok) {
        await response.body?.cancel();
        if (response.status === 409 || response.status === 412) throw new ClientError('Vikunja conflict: read the resource again before editing.');
        throw new ClientError(`Vikunja HTTP ${response.status}. No retry was made. Check permissions or input; for failed writes, inspect current state before retrying.`);
      }
      const chunks: Uint8Array[] = [];
      let size = 0;
      if (response.body) {
        const reader = response.body.getReader();
        for (;;) {
          const { done, value } = await reader.read();
          if (done) break;
          size += value.length;
          if (size > MAX_RESPONSE) { await reader.cancel(); throw new ClientError('Vikunja response exceeded 1 MiB. A write may have succeeded; inspect before retrying.'); }
          chunks.push(value);
        }
      }
      // Defensive redaction also covers an unexpected server echo of the credential.
      const text = Buffer.concat(chunks).toString('utf8').split(token).join('[REDACTED]');
      return { data: text ? JSON.parse(text) : null, etag: response.headers.get('etag') };
    } catch (error) {
      if (error instanceof ClientError) throw error;
      throw new ClientError('Vikunja request failed, was cancelled, redirected, or returned invalid JSON. No retry was made. A write may have succeeded; inspect current state first.');
    }
  }
  async status(signal?: AbortSignal) {
    const result = await this.request('GET', '/token/test', undefined, {}, signal);
    return { origin: this.config.baseUrl, defaultProjectId: this.config.defaultProjectId ?? null, authentication: result.data };
  }
  async list(resource: Resource, options: { projectId?: number; taskId?: number; query?: string; filter?: string; timezone?: string; page?: number } = {}, signal?: AbortSignal) {
    const project = options.projectId ?? this.config.defaultProjectId;
    const path = resource === 'tasks' && project !== undefined ? `/projects/${id(project)}/tasks` : resourcePath(resource, undefined, options.taskId);
    const page = options.page ?? 1;
    id(page);
    if (page > 10000) throw new ClientError('Page exceeds 10000. Narrow the query.');
    if (resource !== 'tasks' && (options.filter !== undefined || options.timezone !== undefined)) throw new ClientError('Task filters only apply to tasks.');
    return (await this.request('GET', path, undefined, { page, per_page: 20, q: options.query,
      filter: options.filter, filter_timezone: options.timezone }, signal)).data;
  }
  async get(resource: Resource, resourceId: number, taskId?: number, signal?: AbortSignal) {
    const result = await this.request('GET', resourcePath(resource, resourceId, taskId), undefined, {}, signal);
    const output = { data: result.data, revision: revision(result.data) };
    // Never issue an edit revision for data that won't fit in a tool result.
    if (Buffer.byteLength(JSON.stringify(output)) > MAX_OUTPUT) throw new ClientError('Resource exceeds tool output limit. Read/edit it in the Vikunja UI instead.');
    return output;
  }
  async create(resource: Resource, fields: Fields, options: { projectId?: number; taskId?: number } = {}, signal?: AbortSignal) {
    const path = resource === 'tasks' ? `/projects/${id(options.projectId ?? this.config.defaultProjectId)}/tasks` : resourcePath(resource, undefined, options.taskId);
    return (await this.request('POST', path, fields, {}, signal)).data;
  }
  async update(resource: Resource, resourceId: number, expectedRevision: string, fields: Fields, taskId?: number, signal?: AbortSignal) {
    if (!/^[a-f0-9]{64}$/.test(expectedRevision) || !Object.keys(fields).length) throw new ClientError('Supply a read revision and at least one changed field.');
    const path = resourcePath(resource, resourceId, taskId);
    const current = await this.request('GET', path, undefined, {}, signal);
    if (revision(current.data) !== expectedRevision) throw new ClientError('Resource changed since read. Read it again before editing.');
    // Best-effort stale-read detection, NOT atomic cross-client locking. v2.6's
    // AutoPatch performs GET then PUT; projects do not even return an ETag.
    return (await this.request('PATCH', path, fields, {}, signal, current.etag ?? undefined)).data;
  }
  async delete(resource: Resource, resourceId: number, taskId?: number, signal?: AbortSignal) {
    await this.request('DELETE', resourcePath(resource, resourceId, taskId), undefined, {}, signal);
    return { deleted: true, resource, id: resourceId };
  }
  async relation(taskId: number, otherTaskId: number, kind: typeof relations[number], remove: boolean, signal?: AbortSignal) {
    if (!relations.includes(kind) || id(taskId) === id(otherTaskId)) throw new ClientError('Invalid task relation.');
    const path = `/tasks/${taskId}/relations`;
    await this.request(remove ? 'DELETE' : 'POST', remove ? `${path}/${kind}/${otherTaskId}` : path,
      remove ? undefined : { other_task_id: otherTaskId, relation_kind: kind }, {}, signal);
    return { taskId, otherTaskId, kind, removed: remove };
  }
  async taskLabel(taskId: number, labelId: number, remove: boolean, signal?: AbortSignal) {
    const path = `/tasks/${id(taskId)}/labels`;
    await this.request(remove ? 'DELETE' : 'POST', remove ? `${path}/${id(labelId)}` : path,
      remove ? undefined : { label_id: id(labelId) }, {}, signal);
    return { taskId, labelId, removed: remove };
  }
}

export function toolResult(data: unknown) {
  const text = JSON.stringify(data);
  const truncated = Buffer.byteLength(text) > MAX_OUTPUT;
  return { content: [{ type: 'text' as const, text: truncated
    ? 'Result exceeds 48KB. The operation may have succeeded. Narrow the search/page or inspect the resource in Vikunja; do not blindly repeat a mutation.' : text }],
    details: { truncated } };
}
