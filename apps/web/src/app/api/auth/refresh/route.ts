import { cookies } from 'next/headers'
import { NextResponse } from 'next/server'

const API_URL = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3001/api'

export async function POST() {
  const cookieStore = await cookies()
  const refreshToken = cookieStore.get('simtc-refresh')?.value

  if (!refreshToken) {
    return NextResponse.json({ message: 'No refresh token' }, { status: 401 })
  }

  const res = await fetch(`${API_URL}/auth/refresh`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ refreshToken }),
    cache: 'no-store',
  })

  if (!res.ok) {
    return NextResponse.json({ message: 'Refresh failed' }, { status: 401 })
  }

  const { accessToken, refreshToken: newRefreshToken } = await res.json()

  const response = NextResponse.json({ accessToken })

  // Atualiza o access token (lido pelo client-api via document.cookie)
  response.cookies.set('simtc-token', accessToken, {
    httpOnly: false,
    path: '/',
    maxAge: 8 * 60 * 60,       // 8h
    sameSite: 'lax',
  })

  // Atualiza o refresh token
  response.cookies.set('simtc-refresh', newRefreshToken, {
    httpOnly: true,
    path: '/',
    maxAge: 30 * 24 * 60 * 60, // 30 dias
    sameSite: 'lax',
  })

  return response
}
