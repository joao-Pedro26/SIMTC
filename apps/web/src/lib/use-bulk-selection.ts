'use client'

import { useCallback, useMemo, useState } from 'react'

/**
 * Hook genérico para seleção múltipla via checkbox em listas (ex.: linhas de
 * uma tabela). Mantém um Set de IDs selecionados e helpers de toggle/limpar.
 *
 * Usado pelas ações em lote da listagem de participantes (excluir, enviar
 * certificados/relatórios por e-mail, baixar ZIP) — ver
 * brainstorm-acoes-lote-participantes.md.
 *
 * `selectableIds` deve conter apenas os IDs que podem de fato ser selecionados
 * no momento (ex.: já exclui participantes com avaliação em andamento, no
 * caso da exclusão em lote). O hook filtra automaticamente qualquer ID
 * selecionado que não esteja mais nessa lista (linha sumiu por causa de um
 * filtro, foi excluída em outra aba etc.).
 */
export function useBulkSelection(selectableIds: string[]) {
  const [selected, setSelected] = useState<Set<string>>(new Set())

  const selectableSet = useMemo(() => new Set(selectableIds), [selectableIds])

  const selectedIds = useMemo(
    () => Array.from(selected).filter((id) => selectableSet.has(id)),
    [selected, selectableSet],
  )

  const toggle = useCallback((id: string) => {
    setSelected((prev) => {
      const next = new Set(prev)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }, [])

  const toggleAll = useCallback(() => {
    setSelected((prev) => {
      const allCurrentlySelected =
        selectableIds.length > 0 && selectableIds.every((id) => prev.has(id))
      return allCurrentlySelected ? new Set() : new Set(selectableIds)
    })
  }, [selectableIds])

  const clear = useCallback(() => setSelected(new Set()), [])

  const isSelected = useCallback((id: string) => selected.has(id), [selected])

  const allSelected = selectableIds.length > 0 && selectableIds.every((id) => selected.has(id))
  const someSelected = selectedIds.length > 0 && !allSelected

  return {
    selectedIds,
    selectedCount: selectedIds.length,
    isSelected,
    toggle,
    toggleAll,
    clear,
    allSelected,
    someSelected,
  }
}
