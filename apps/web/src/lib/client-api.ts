'use client'

const API_URL = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3001/api'

function getToken(cookieName: string): string | null {
  if (typeof document === 'undefined') return null
  const match = document.cookie
    .split('; ')
    .find((c) => c.startsWith(`${cookieName}=`))
  return match ? decodeURIComponent(match.split('=')[1]) : null
}

function setTokenCookie(value: string) {
  document.cookie = `simtc-token=${encodeURIComponent(value)}; path=/; max-age=${8 * 60 * 60}; samesite=lax`
}

// Singleton: se um refresh já está em andamento, todas as requisições que
// recebem 401 simultaneamente aguardam o mesmo refresh em vez de disparar vários.
let refreshingPromise: Promise<string | null> | null = null

async function doRefresh(): Promise<string | null> {
  if (refreshingPromise) return refreshingPromise

  refreshingPromise = fetch('/api/auth/refresh', { method: 'POST', cache: 'no-store' })
    .then(async (res) => {
      if (!res.ok) return null
      const { accessToken } = await res.json()
      setTokenCookie(accessToken)
      return accessToken as string
    })
    .catch(() => null)
    .finally(() => { refreshingPromise = null })

  return refreshingPromise
}

async function clientFetch<T>(
  path: string,
  options?: RequestInit,
  isRetry = false,
): Promise<T> {
  const token = getToken('simtc-token')
  const isFormData = options?.body instanceof FormData

  const res = await fetch(`${API_URL}${path}`, {
    ...options,
    headers: {
      ...(!isFormData ? { 'Content-Type': 'application/json' } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...options?.headers,
    },
  })

  if (res.status === 401 && !isRetry) {
    const newToken = await doRefresh()
    if (newToken) {
      return clientFetch<T>(path, options, true)
    }
    if (typeof window !== 'undefined') window.location.href = '/login'
    throw new Error('Sessão expirada. Faça login novamente.')
  }

  if (!res.ok) {
    const error = await res.json().catch(() => ({ message: res.statusText }))
    throw new Error(error.message ?? `Erro ${res.status}`)
  }

  if (res.status === 204) return undefined as T
  return res.json() as Promise<T>
}

export const clientApi = {
  get:    <T>(path: string)                => clientFetch<T>(path),
  post:   <T>(path: string, body: unknown) => clientFetch<T>(path, { method: 'POST',   body: JSON.stringify(body) }),
  put:    <T>(path: string, body: unknown) => clientFetch<T>(path, { method: 'PUT',    body: JSON.stringify(body) }),
  patch:  <T>(path: string, body: unknown) => clientFetch<T>(path, { method: 'PATCH',  body: JSON.stringify(body) }),
  delete: <T>(path: string)                => clientFetch<T>(path, { method: 'DELETE' }),
  upload: <T>(path: string, fd: FormData)  => clientFetch<T>(path, { method: 'PATCH',  body: fd }),
}
