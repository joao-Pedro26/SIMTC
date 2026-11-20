'use client'

import { createContext, useContext, useEffect, useRef, type MutableRefObject } from 'react'

export interface DrawerGuard {
  /** Há alterações ainda não salvas no formulário do drawer. */
  dirty: boolean
  /**
   * Salva o formulário. Quem salva costuma fechar o drawer sozinho quando dá certo;
   * quem não fecha devolve `true` (salvou) e o Drawer fecha em seguida.
   */
  save: () => boolean | void | Promise<boolean | void>
}

export const DrawerGuardContext = createContext<MutableRefObject<DrawerGuard | null> | null>(null)

/**
 * Faz o Drawer perguntar "salvar, descartar ou continuar editando" ao ser fechado
 * (clicar fora, X ou Esc) com o formulário alterado.
 *
 * `value` é tudo que o usuário pode editar (arquivos escolhidos entram como
 * boolean, pois não serializam). A primeira renderização é o estado "limpo";
 * se o formulário se preenche sozinho depois (dados carregados), use o
 * `resetBaseline` devolvido para tomar o estado atual como o novo ponto de partida.
 */
export function useDrawerGuard(
  value: unknown,
  save: () => boolean | void | Promise<boolean | void>,
  options: {
    /** false = nunca considera alterado (ex.: modo somente leitura). */
    enabled?: boolean
    /** Estado "limpo" calculado a cada render, para formulários cujo valor inicial muda depois de abrir. */
    baseline?: unknown
  } = {},
) {
  const { enabled = true, baseline: explicitBaseline } = options
  const guard = useContext(DrawerGuardContext)
  const serialized = JSON.stringify(value)
  const baseline = useRef<string | null>(null)
  if (baseline.current === null) baseline.current = serialized
  const cleanState = explicitBaseline === undefined ? baseline.current : JSON.stringify(explicitBaseline)

  // Atualizado a cada render: o Drawer lê só no momento de fechar.
  useEffect(() => {
    if (!guard) return
    guard.current = { dirty: enabled && serialized !== cleanState, save }
  })

  useEffect(() => {
    return () => {
      if (guard) guard.current = null
    }
  }, [guard])

  return {
    /** Toma `next` (ou o valor atual) como o estado "limpo". */
    resetBaseline: (next?: unknown) => {
      baseline.current = JSON.stringify(next === undefined ? value : next)
    },
  }
}
