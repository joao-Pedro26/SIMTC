'use server'

import { cookies } from 'next/headers'
import { redirect } from 'next/navigation'

const API_URL = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3001/api'

export type AuthMethod = 'password' | 'otp' | 'not_found'

// Decodifica o payload de um JWT sem verificar assinatura — só para
// extrair o "role" e decidir para onde redirecionar logo após o login.
// A validação de verdade acontece no backend e no middleware.
function decodeRole(token: string): string | undefined {
  try {
    const payload = JSON.parse(Buffer.from(token.split('.')[1], 'base64').toString('utf-8'))
    return payload?.role
  } catch {
    return undefined
  }
}

export async function checkEmailAction(
  email: string,
): Promise<{ authMethod: AuthMethod; error?: string }> {
  try {
    const res = await fetch(`${API_URL}/auth/check-email`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email }),
      cache: 'no-store',
    })

    if (!res.ok) {
      return { authMethod: 'not_found', error: 'Não foi possível verificar este e-mail.' }
    }

    const data = await res.json()
    return { authMethod: data.authMethod }
  } catch {
    return { authMethod: 'not_found', error: 'Não foi possível conectar ao servidor.' }
  }
}

export async function requestOtpAction(email: string): Promise<{ error?: string }> {
  try {
    const res = await fetch(`${API_URL}/auth/client/request-code`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email }),
      cache: 'no-store',
    })

    if (!res.ok) {
      return { error: 'Não foi possível enviar o código. Tente novamente.' }
    }

    return {}
  } catch {
    return { error: 'Não foi possível conectar ao servidor.' }
  }
}

export async function verifyOtpAction(
  email: string,
  code: string,
): Promise<{ error?: string; role?: string }> {
  let data: { accessToken: string; refreshToken: string }

  try {
    const res = await fetch(`${API_URL}/auth/client/verify`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, code }),
      cache: 'no-store',
    })

    if (!res.ok) {
      const body = await res.json().catch(() => ({}))
      return { error: body.message ?? 'Código inválido ou expirado.' }
    }

    data = await res.json()
  } catch {
    return { error: 'Não foi possível conectar ao servidor.' }
  }

  const cookieStore = await cookies()

  cookieStore.set('simtc-token', data.accessToken, {
    httpOnly: false,
    path: '/',
    maxAge: 8 * 60 * 60,
    sameSite: 'lax',
  })

  cookieStore.set('simtc-refresh', data.refreshToken, {
    httpOnly: true,
    path: '/',
    maxAge: 30 * 24 * 60 * 60,
    sameSite: 'lax',
  })

  return { role: decodeRole(data.accessToken) }
}

export async function loginAction(
  email: string,
  password: string,
): Promise<{ error?: string; role?: string }> {
  let data: { accessToken: string; refreshToken: string }

  try {
    const res = await fetch(`${API_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password }),
      cache: 'no-store',
    })

    if (!res.ok) {
      const body = await res.json().catch(() => ({}))
      return { error: body.message ?? 'Credenciais inválidas' }
    }

    data = await res.json()
  } catch {
    return { error: 'Não foi possível conectar ao servidor.' }
  }

  const cookieStore = await cookies()

  // Access token — precisa ser acessível via document.cookie (client-api) e via cookies() (apiFetch)
  cookieStore.set('simtc-token', data.accessToken, {
    httpOnly: false,
    path: '/',
    maxAge: 8 * 60 * 60,       // 8h (mesmo TTL do JWT)
    sameSite: 'lax',
  })

  // Refresh token — apenas server-side
  cookieStore.set('simtc-refresh', data.refreshToken, {
    httpOnly: true,
    path: '/',
    maxAge: 30 * 24 * 60 * 60, // 30 dias
    sameSite: 'lax',
  })

  return { role: decodeRole(data.accessToken) }
}

export async function forgotPasswordAction(email: string): Promise<{ error?: string }> {
  try {
    const res = await fetch(`${API_URL}/auth/forgot-password`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email }),
      cache: 'no-store',
    })

    if (!res.ok) {
      return { error: 'Não foi possível processar a solicitação. Tente novamente.' }
    }

    return {}
  } catch {
    return { error: 'Não foi possível conectar ao servidor.' }
  }
}

export async function resetPasswordAction(
  token: string,
  newPassword: string,
): Promise<{ error?: string }> {
  try {
    const res = await fetch(`${API_URL}/auth/reset-password`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token, newPassword }),
      cache: 'no-store',
    })

    if (!res.ok) {
      const body = await res.json().catch(() => ({}))
      return { error: body.message ?? 'Token inválido ou expirado.' }
    }

    return {}
  } catch {
    return { error: 'Não foi possível conectar ao servidor.' }
  }
}

export async function logoutAction(): Promise<void> {
  const cookieStore = await cookies()
  cookieStore.delete('simtc-token')
  cookieStore.delete('simtc-refresh')
  redirect('/login')
}
