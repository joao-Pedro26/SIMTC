'use client'

import { useDrawerGuard } from './drawer-guard'

interface DrawerGuardBridgeProps {
  dirty: boolean
  save: () => boolean | void | Promise<boolean | void>
}

/**
 * Para quem renderiza o <Drawer> no mesmo componente em que guarda o estado
 * "alterado": o hook `useDrawerGuard` só enxerga o Drawer a partir de um filho,
 * então este componente (sem saída visual) vai dentro do Drawer e faz a ponte.
 */
export function DrawerGuardBridge({ dirty, save }: DrawerGuardBridgeProps) {
  useDrawerGuard(dirty, save, { baseline: false })
  return null
}
