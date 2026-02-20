export type ApiError = { error: { code: string; message: string; details?: any } }

export function getToken(): string | null {
  return localStorage.getItem('token')
}

export function setToken(token: string | null) {
  if (token) localStorage.setItem('token', token)
  else localStorage.removeItem('token')
}

async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' }
  const token = getToken()
  if (token) headers['Authorization'] = `Bearer ${token}`

  const res = await fetch(`/api/${path}`, { ...options, headers: { ...headers, ...(options.headers as any) } })
  if (res.status === 204) return undefined as any
  const data = await res.json().catch(() => ({}))
  if (!res.ok) throw data as ApiError
  return data as T
}

export const api = {
  register: (email: string, password: string) =>
    request<{ token: string; user: any }>('auth/register', { method: 'POST', body: JSON.stringify({ email, password }) }),
  login: (email: string, password: string) =>
    request<{ token: string; user: any }>('auth/login', { method: 'POST', body: JSON.stringify({ email, password }) }),

  listProjects: () => request<{ projects: any[] }>('projects'),
  createProject: (name: string) => request<{ project: any }>('projects', { method: 'POST', body: JSON.stringify({ name }) }),
  updateProject: (id: number, name: string) => request<{ project: any }>(`projects/${id}`, { method: 'PATCH', body: JSON.stringify({ name }) }),
  deleteProject: (id: number) => request<void>(`projects/${id}`, { method: 'DELETE' }),
  rotateProjectToken: (id: number) => request<{ project: any }>(`projects/${id}/rotate-token`, { method: 'POST' }),

  dashboard: (id: number) => request<any>(`projects/${id}/dashboard`),
  topErrors: (id: number) => request<any>(`projects/${id}/errors/top`),
  flaky: (id: number) => request<any>(`projects/${id}/flaky`),
  similarInProject: (projectId: number, fp: string) => request<any>(`projects/${projectId}/errors/${encodeURIComponent(fp)}/similar`),

  listRuns: (projectId: number) => request<{ runs: any[] }>(`projects/${projectId}/runs`),
  getRun: (runId: number) => request<any>(`runs/${runId}`),
  diffRun: (runId: number) => request<any>(`runs/${runId}/diff`),
  annotateTestCase: (testCaseId: number, annotation: string) =>
    request<any>(`testcases/${testCaseId}/annotate`, { method: 'POST', body: JSON.stringify({ annotation }) }),

  uploadRunAttachment: (runId: number, fileName: string, mime: string, contentBase64: string) =>
    request<any>(`runs/${runId}/attachments`, { method: 'POST', body: JSON.stringify({ fileName, mime, contentBase64 }) })
}
