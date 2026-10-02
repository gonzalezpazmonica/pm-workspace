export class ApiError extends Error {
  constructor(
    public status: number,
    public code: string,
    message: string,
  ) {
    super(message || code)
  }
}

/** Same-origin JSON call. Mutations carry the markers the server requires (Origin is set by the browser). */
export async function api<T = any>(method: string, path: string, body?: unknown): Promise<T> {
  const headers: Record<string, string> = { Accept: 'application/json' }
  if (method !== 'GET') {
    headers['X-Space-Request'] = '1'
    headers['Content-Type'] = 'application/json'
  }
  const res = await fetch(path, {
    method,
    headers,
    credentials: 'same-origin',
    body: body === undefined ? undefined : JSON.stringify(body),
  })
  const ctype = res.headers.get('content-type') ?? ''
  const data = ctype.includes('json') ? await res.json().catch(() => null) : await res.text()
  if (!res.ok) {
    const env = (data && typeof data === 'object' ? data : {}) as { code?: string; message?: string }
    throw new ApiError(res.status, env.code ?? 'HTTP_' + res.status, env.message ?? '')
  }
  return data as T
}

export function newKey(prefix: string): string {
  return `${prefix}-${crypto.randomUUID()}`
}
