'use client'

import { useState, useEffect, useRef } from 'react'
import { X, Loader2 } from 'lucide-react'
import { AssessmentConfirmDialog } from './assessment-confirm-dialog'
import { clientApi } from '@/lib/client-api'
import { calculateCategoryScore, calculateOverallScore, getApprovalLabel } from '@simtc/shared-types'
import styles from './assessment-drawer.module.css'

// ── Tipos da API ──────────────────────────────────────────────────────────────

interface InfractionNote {
  id: string
  noteType: 'B' | 'PM' | 'M'
  comment?: string | null
  deduction: number
}

interface AssessmentInfraction {
  id: string
  description: string
  order: number
  notes: InfractionNote[]
}

interface AssessmentCategory {
  id: string
  code: string
  name: string
  description?: string | null
  order: number
  infractions: AssessmentInfraction[]
}

interface SelectedNote {
  infractionNoteId: string
  noteType: 'B' | 'PM' | 'M'
  deduction: number
  categoryId: string
}

// ── Props ─────────────────────────────────────────────────────────────────────

interface AssessmentDrawerProps {
  open: boolean
  participantName: string
  trainingParticipantId: string
  onClose: () => void
  onSaved: () => void
}

// ── Componente ────────────────────────────────────────────────────────────────

export function AssessmentDrawer({
  open,
  participantName,
  trainingParticipantId,
  onClose,
  onSaved,
}: AssessmentDrawerProps) {
  const [categories, setCategories] = useState<AssessmentCategory[]>([])
  const [loadingCategories, setLoadingCategories] = useState(false)
  const [selectedCategoryId, setSelectedCategoryId] = useState<string | null>(null)
  const [selections, setSelections] = useState<Map<string, SelectedNote>>(new Map())
  const startTimeRef = useRef<Date | null>(null)
  const [showConfirm, setShowConfirm] = useState(false)
  const [showCancelConfirm, setShowCancelConfirm] = useState(false)
  const [endTime, setEndTime] = useState<Date | null>(null)
  const [saving, setSaving] = useState(false)
  const [saveError, setSaveError] = useState('')

  // Carrega categorias e captura horário de início quando o modal abre
  useEffect(() => {
    if (!open) return

    startTimeRef.current = new Date()

    async function loadCategories() {
      setLoadingCategories(true)
      setSaveError('')
      try {
        const data = await clientApi.get<AssessmentCategory[]>('/assessment-categories')
        setCategories(data)
        setSelectedCategoryId(data[0]?.id ?? null)
      } catch {
        setSaveError('Erro ao carregar categorias de avaliação')
      } finally {
        setLoadingCategories(false)
      }
    }

    loadCategories()
  }, [open])

  // Reseta estado ao fechar
  useEffect(() => {
    if (!open) {
      setCategories([])
      setSelectedCategoryId(null)
      setSelections(new Map())
      startTimeRef.current = null
      setShowConfirm(false)
      setShowCancelConfirm(false)
      setEndTime(null)
      setSaveError('')
    }
  }, [open])

  // Fecha com ESC — mas só se nenhum sub-dialog estiver aberto
  useEffect(() => {
    if (!open) return
    function onKey(e: KeyboardEvent) {
      if (e.key === 'Escape') {
        if (showConfirm) { setShowConfirm(false); return }
        if (showCancelConfirm) { setShowCancelConfirm(false); return }
        setShowCancelConfirm(true)
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [open, showConfirm, showCancelConfirm])

  function toggleNote(infraction: AssessmentInfraction, note: InfractionNote, categoryId: string) {
    setSelections((prev) => {
      const next = new Map(prev)
      const current = next.get(infraction.id)
      if (current?.infractionNoteId === note.id) {
        next.delete(infraction.id)
      } else {
        next.set(infraction.id, {
          infractionNoteId: note.id,
          noteType: note.noteType,
          deduction: note.deduction,
          categoryId,
        })
      }
      return next
    })
  }

  function calculateScores() {
    // Agrupa deduções por categoria
    const byCategory = new Map<string, number[]>()
    for (const sel of Array.from(selections.values())) {
      if (!byCategory.has(sel.categoryId)) byCategory.set(sel.categoryId, [])
      byCategory.get(sel.categoryId)!.push(sel.deduction)
    }
    // Todas as categorias começam em 100% — desconta apenas o que foi marcado
    const catScores = categories.map((cat) => ({
      categoryId: cat.id,
      score: calculateCategoryScore(byCategory.get(cat.id) ?? [], cat.infractions.length),
    }))
    const overall = calculateOverallScore(catScores.map((cs) => cs.score))
    return { catScores, overall }
  }

  function handleSalvar() {
    const captured = new Date()
    setEndTime(captured)
    setShowConfirm(true)
  }

  function handleCancelar() {
    setShowCancelConfirm(true)
  }

  function handleCancelConfirmed() {
    setShowCancelConfirm(false)
    onClose()
  }

  async function handleConfirm() {
    if (!startTimeRef.current || !endTime) return
    setSaving(true)
    setSaveError('')
    try {
      const today = new Date()
      const items = Array.from(selections.values()).map((sel) => ({
        infractionNoteId: sel.infractionNoteId,
      }))

      await clientApi.post('/practical-assessments/sync', [
        {
          trainingParticipantId,
          date: today.toISOString().split('T')[0],
          startTime: startTimeRef.current.toISOString(),
          endTime: endTime.toISOString(),
          items,
        },
      ])

      onSaved()
    } catch (e) {
      setSaveError(e instanceof Error ? e.message : 'Erro ao salvar avaliação')
      setShowConfirm(false)
    } finally {
      setSaving(false)
    }
  }

  const selectedCategory = categories.find((c) => c.id === selectedCategoryId)
  const { catScores, overall } = calculateScores()
  const catScoreMap = new Map(catScores.map((cs) => [cs.categoryId, cs.score]))

  const confirmCategoryScores = categories
    .map((c) => ({ code: c.code, name: c.name, score: catScoreMap.get(c.id) ?? 100 }))

  if (!open) return null

  return (
    <>
      {/* ── Overlay ── */}
      <div className={styles.overlay} role="dialog" aria-modal="true" aria-labelledby="assessment-modal-title">

        {/* ── Modal ── */}
        <div className={styles.modal}>

          {/* Header */}
          <div className={styles.modalHeader}>
            <h2 id="assessment-modal-title" className={styles.modalTitle}>
              Avaliando — {participantName}
            </h2>
            <button
              className={styles.closeBtn}
              onClick={handleCancelar}
              title="Fechar"
              aria-label="Fechar modal de avaliação"
            >
              <X size={18} />
            </button>
          </div>

          {/* Body */}
          <div className={styles.modalBody}>
            {loadingCategories ? (
              <div className={styles.loadingState}>
                <Loader2 size={24} className={styles.spinner} />
              </div>
            ) : saveError && categories.length === 0 ? (
              <div className={styles.errorState}>
                <p>{saveError}</p>
              </div>
            ) : (
              <div className={styles.twoPanel}>
                {/* Sidebar esquerda */}
                <nav className={styles.sidebar}>
                  {categories.map((cat) => {
                    const score = catScoreMap.get(cat.id)
                    const isActive = selectedCategoryId === cat.id
                    return (
                      <button
                        key={cat.id}
                        className={`${styles.catBtn} ${isActive ? styles.catBtnActive : ''}`}
                        onClick={() => setSelectedCategoryId(cat.id)}
                      >
                        <span className={styles.catCode}>{cat.code}</span>
                        <span className={styles.catName}>{cat.name}</span>
                        {score !== undefined && (
                          <span className={`${styles.catScore} ${score < 70 ? styles.catScoreLow : score >= 85 ? styles.catScoreHigh : styles.catScoreMid}`}>
                            {Math.round(score)}%
                          </span>
                        )}
                      </button>
                    )
                  })}
                </nav>

                {/* Painel direito */}
                <div className={styles.mainPanel}>
                  {selectedCategory ? (
                    <>
                      <div className={styles.categoryHeader}>
                        <span className={styles.categoryCode}>{selectedCategory.code}</span>
                        <span className={styles.categoryTitle}>{selectedCategory.name}</span>
                      </div>
                      {selectedCategory.description && (
                        <p className={styles.categoryDescription}>{selectedCategory.description}</p>
                      )}
                      <ul className={styles.infractionList}>
                        {selectedCategory.infractions.map((infraction, idx) => {
                          const currentSel = selections.get(infraction.id)
                          return (
                            <li key={infraction.id} className={styles.infractionItem}>
                              <div className={styles.infractionRow}>
                                <span className={styles.infractionIndex}>{idx + 1}.</span>
                                <span className={styles.infractionDesc}>{infraction.description}</span>
                              </div>
                              <div className={styles.noteButtons}>
                                {(['B', 'PM', 'M'] as const).map((noteType) => {
                                  const note = infraction.notes.find((n) => n.noteType === noteType)
                                  if (!note) return null
                                  const isSelected = currentSel?.infractionNoteId === note.id
                                  return (
                                    <button
                                      key={note.id}
                                      className={`${styles.noteBtn} ${styles[`noteBtn${noteType.replace('/', '')}`]} ${isSelected ? styles.noteBtnSelected : ''}`}
                                      onClick={() => toggleNote(infraction, note, selectedCategory.id)}
                                      title={note.comment ?? noteType}
                                    >
                                      {noteType}
                                    </button>
                                  )
                                })}
                              </div>
                            </li>
                          )
                        })}
                      </ul>
                    </>
                  ) : (
                    <p className={styles.emptyState}>Nenhuma categoria disponível</p>
                  )}
                </div>
              </div>
            )}
          </div>

          {/* Footer */}
          <div className={styles.footer}>
            <div className={styles.footerScores}>
              {categories.map((cat) => {
                const score = catScoreMap.get(cat.id)
                return (
                  <span key={cat.id} className={styles.footerScoreItem}>
                    <span className={styles.footerCode}>{cat.code}</span>
                    <span className={score !== undefined ? styles.footerValue : styles.footerDash}>
                      {score !== undefined ? `${Math.round(score)}%` : '—'}
                    </span>
                  </span>
                )
              })}
              <span className={styles.footerOverall}>
                Geral: <strong>{catScores.length > 0 ? `${Math.round(overall)}%` : '—'}</strong>
              </span>
            </div>
            {saveError && <span className={styles.footerError}>{saveError}</span>}
            <div className={styles.footerActions}>
              <button className={styles.cancelBtn} onClick={handleCancelar} disabled={saving}>
                Cancelar
              </button>
              <button className={styles.saveBtn} onClick={handleSalvar} disabled={saving}>
                Salvar
              </button>
            </div>
          </div>

          {/* Confirm dialog de cancelamento */}
          {showCancelConfirm && (
            <div className={styles.cancelOverlay}>
              <div className={styles.cancelDialog}>
                <p className={styles.cancelDialogTitle}>Cancelar avaliação?</p>
                <p className={styles.cancelDialogBody}>Todo o progresso será perdido e a avaliação não será salva.</p>
                <div className={styles.cancelDialogActions}>
                  <button className={styles.cancelDialogKeep} onClick={() => setShowCancelConfirm(false)}>
                    Continuar avaliando
                  </button>
                  <button className={styles.cancelDialogConfirm} onClick={handleCancelConfirmed}>
                    Sim, cancelar
                  </button>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Confirm dialog de salvar */}
      {showConfirm && startTimeRef.current && endTime && (
        <AssessmentConfirmDialog
          startTime={startTimeRef.current}
          endTime={endTime}
          categoryScores={confirmCategoryScores}
          overallScore={overall}
          approvalLabel={getApprovalLabel(overall)}
          saving={saving}
          onConfirm={handleConfirm}
          onCancel={() => setShowConfirm(false)}
        />
      )}
    </>
  )
}
