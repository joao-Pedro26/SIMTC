'use client'

import { useCallback, useRef, useState } from 'react'

/**
 * Impede que um envio seja disparado de novo enquanto o anterior não terminou
 * (vários cliques em "Salvar" criando o mesmo registro várias vezes).
 *
 * A trava fica num ref, e não só no estado: cliques seguidos chegam antes de o
 * React renderizar de novo, e um `useState` sozinho ainda deixaria o segundo passar.
 * `pending` serve para desabilitar o botão e mostrar "Salvando...".
 *
 * `run(fn)` executa `fn` só se não houver outro envio em andamento; se houver,
 * devolve `undefined` sem chamar nada.
 */
export function useSubmitLock() {
  const locked = useRef(false)
  const [pending, setPending] = useState(false)

  const run = useCallback(async <T,>(fn: () => T | Promise<T>): Promise<T | undefined> => {
    if (locked.current) return undefined
    locked.current = true
    setPending(true)
    try {
      return await fn()
    } finally {
      locked.current = false
      setPending(false)
    }
  }, [])

  return { pending, run }
}
