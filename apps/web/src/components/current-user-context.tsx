'use client'

import { createContext, useContext, useEffect, useState } from 'react'
import { clientApi } from '@/lib/client-api'

export type Role = 'ADMIN' | 'CONSULTANT' | 'CLIENT'

export interface CurrentUser {
  id: string
  name: string
  email: string
  role: Role
}

interface CurrentUserContextValue {
  me: CurrentUser | null
  loading: boolean
  /** Atalho: `true` quando o usuário logado é CONSULTANT (usado para travar telas em modo somente-leitura) */
  isConsultant: boolean
}

const CurrentUserContext = createContext<CurrentUserContextValue>({
  me: null,
  loading: true,
  isConsultant: false,
})

// Busca `/auth/me` uma única vez e compartilha o resultado com toda a árvore
// (Sidebar, páginas restritas por papel, etc.) em vez de cada componente
// disparar sua própria requisição.
export function CurrentUserProvider({ children }: { children: React.ReactNode }) {
  const [me, setMe] = useState<CurrentUser | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    clientApi.get<CurrentUser>('/auth/me')
      .then(setMe)
      .catch(() => { /* silencioso — mantém null se falhar */ })
      .finally(() => setLoading(false))
  }, [])

  return (
    <CurrentUserContext.Provider value={{ me, loading, isConsultant: me?.role === 'CONSULTANT' }}>
      {children}
    </CurrentUserContext.Provider>
  )
}

export function useCurrentUser() {
  return useContext(CurrentUserContext)
}
