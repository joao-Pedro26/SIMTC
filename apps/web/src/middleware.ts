import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

const API_URL = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3001/api'

// Rotas públicas que não precisam de autenticação
const PUBLIC_ROUTES = ['/login', '/register', '/forgot-password', '/reset-password']

type Role = 'ADMIN' | 'CONSULTANT' | 'CLIENT'

// Home de cada papel — destino do redirect quando há acesso cruzado
const ROLE_HOME: Record<Role, string> = {
  ADMIN:      '/dashboard',
  CONSULTANT: '/training-sessions',
  CLIENT:     '/my-company',
}

// Prefixos de rota com restrição de papel.
const ROLE_ROUTES: { prefix: string; roles: Role[] }[] = [
  { prefix: '/dashboard',             roles: ['ADMIN'] },
  { prefix: '/assessment-categories', roles: ['ADMIN', 'CONSULTANT'] },
  { prefix: '/companies',             roles: ['ADMIN', 'CONSULTANT'] },
  { prefix: '/consultants',           roles: ['ADMIN'] },
  { prefix: '/courses',               roles: ['ADMIN', 'CONSULTANT'] },
  { prefix: '/demand-pipeline',       roles: ['ADMIN'] },
  { prefix: '/reports',               roles: ['ADMIN'] },
  { prefix: '/training-sessions',     roles: ['ADMIN', 'CONSULTANT'] },
  { prefix: '/profile',               roles: ['CONSULTANT'] },
  { prefix: '/my-company',            roles: ['CLIENT'] },
]

// Decodifica o payload de um JWT sem verificar assinatura.
// Seguro aqui porque o backend já validou — só precisamos ler o role.
function decodeJwtPayload(token: string): Record<string, unknown> | null {
  try {
    const base64Url = token.split('.')[1]
    if (!base64Url) return null
    // base64url → base64 padrão
    const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/')
    return JSON.parse(atob(base64))
  } catch {
    return null
  }
}

function homeForRole(role: string): string {
  return ROLE_HOME[role as Role] ?? '/login'
}

function isAllowed(pathname: string, role: string): boolean {
  const restriction = ROLE_ROUTES.find(({ prefix }) => pathname.startsWith(prefix))
  if (!restriction) return true
  return restriction.roles.includes(role as Role)
}

export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl

  // Deixa passar rotas públicas sem checar nada
  if (PUBLIC_ROUTES.some((r) => pathname.startsWith(r))) {
    return NextResponse.next()
  }

  const token   = request.cookies.get('simtc-token')?.value
  const refresh = request.cookies.get('simtc-refresh')?.value

  // Access token presente → decodifica e verifica acesso por papel
  if (token) {
    const payload = decodeJwtPayload(token)
    const role = payload?.role as string | undefined

    if (role && !isAllowed(pathname, role)) {
      return NextResponse.redirect(new URL(homeForRole(role), request.url))
    }

    return NextResponse.next()
  }

  // Nenhum dos dois tokens → força login
  if (!refresh) {
    const loginUrl = new URL('/login', request.url)
    loginUrl.searchParams.set('redirect', pathname)
    return NextResponse.redirect(loginUrl)
  }

  // Access token expirou mas refresh token ainda existe → tenta renovar aqui
  // mesmo, antes de qualquer redirecionamento. O cliente sequer percebe.
  try {
    const res = await fetch(`${API_URL}/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refreshToken: refresh }),
      cache: 'no-store',
    })

    if (!res.ok) {
      // Refresh token inválido ou expirado → força login
      const loginUrl = new URL('/login', request.url)
      loginUrl.searchParams.set('redirect', pathname)
      return NextResponse.redirect(loginUrl)
    }

    const { accessToken, refreshToken: newRefreshToken } = await res.json()

    // Verifica acesso por papel com o token recém-emitido
    const payload = decodeJwtPayload(accessToken)
    const role = payload?.role as string | undefined

    if (role && !isAllowed(pathname, role)) {
      return NextResponse.redirect(new URL(homeForRole(role), request.url))
    }

    // Deixa o request original seguir, mas já injeta os dois cookies novos
    const response = NextResponse.next()

    response.cookies.set('simtc-token', accessToken, {
      httpOnly: false,           // precisa ser lido pelo client-api via document.cookie
      path: '/',
      maxAge: 8 * 60 * 60,      // 8h
      sameSite: 'lax',
    })

    response.cookies.set('simtc-refresh', newRefreshToken, {
      httpOnly: true,
      path: '/',
      maxAge: 30 * 24 * 60 * 60, // 30 dias
      sameSite: 'lax',
    })

    return response
  } catch {
    // Falha de rede ao contactar o backend → força login
    const loginUrl = new URL('/login', request.url)
    loginUrl.searchParams.set('redirect', pathname)
    return NextResponse.redirect(loginUrl)
  }
}

export const config = {
  matcher: ['/((?!api|_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)'],
}
