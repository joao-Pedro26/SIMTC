'use client'

import { useCallback, useEffect, useRef, useState } from 'react'
import { Check, PenLine, RotateCcw, Trash2 } from 'lucide-react'
import type { SignatureAction } from '@simtc/shared-types'
import { SignatureModal } from '@/components/signature-modal/signature-modal'
import { PUBLIC_API_URL, useSignaturePreview } from './use-signature-preview'
import styles from './signature-card.module.css'

/** Valor entregue ao fluxo do formulário a cada mudança. `blob` só existe no estado C. */
export interface SignatureValue {
  action: SignatureAction
  blob?: Blob
}

export interface SignatureCardProps {
  qrToken: string
  /** CPF com ou sem máscara; normalizado para dígitos internamente. */
  cpf: string
  /** E-mail digitado; aparado internamente. */
  email: string
  /** Chamado sempre que a ação ou o blob mudam. A função pode mudar de identidade sem problema. */
  onChange: (value: SignatureValue) => void
}

interface Draft {
  blob: Blob
  previewUrl: string
}

function formatDate(iso: string): string {
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return ''
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${pad(d.getDate())}/${pad(d.getMonth() + 1)}/${d.getFullYear()}`
}

/**
 * Card "Assinatura" do formulário de inscrição (estados A/B/C/D do brainstorm §5).
 * - A: vazio, abre o modal.
 * - B: assinatura salva para o CPF + e-mail (prévia do servidor). "Usar esta" é o padrão.
 * - C: nova assinatura desenhada no aparelho (objectURL local). Refazer / Remover.
 * - D: CPF com assinatura, mas e-mail não confere (locked). Sem ações.
 */
export function SignatureCard({ qrToken, cpf, email, onChange }: SignatureCardProps) {
  const preview = useSignaturePreview(qrToken, cpf, email)
  const [draft, setDraft] = useState<Draft | null>(null)
  const [modalOpen, setModalOpen] = useState(false)
  const [removeError, setRemoveError] = useState('')
  const [removing, setRemoving] = useState(false)

  // Dono da objectURL da nova assinatura: revoga ao trocar o draft e ao desmontar.
  useEffect(() => {
    return () => {
      if (draft) URL.revokeObjectURL(draft.previewUrl)
    }
  }, [draft])

  // Entrega o valor ao fluxo. Ref evita que uma onChange nova dispare o efeito de novo.
  const onChangeRef = useRef(onChange)
  useEffect(() => {
    onChangeRef.current = onChange
  })

  const mode: 'A' | 'B' | 'C' | 'D' | 'loading' = draft
    ? 'C'
    : preview.state === 'loading'
      ? 'loading'
      : preview.state === 'found'
        ? 'B'
        : preview.state === 'locked'
          ? 'D'
          : 'A'

  const blob = draft?.blob
  const action: SignatureAction = mode === 'C' ? 'replace' : mode === 'B' ? 'keep' : 'none'

  useEffect(() => {
    onChangeRef.current({ action, blob })
  }, [action, blob])

  const handleConfirm = useCallback((newBlob: Blob, previewUrl: string) => {
    setDraft({ blob: newBlob, previewUrl })
    setRemoveError('')
    setModalOpen(false)
  }, [])

  const closeModal = useCallback(() => setModalOpen(false), [])

  function removeDraft() {
    setDraft(null)
    // Volta a B se havia assinatura salva; a prévia é consultada de novo porque a signed URL pode ter expirado.
    if (preview.state === 'found') preview.refetch()
  }

  async function removeSaved() {
    const ok = window.confirm('Remover sua assinatura salva? Ela deixará de ser usada nos seus certificados.')
    if (!ok) return

    const digits = cpf.replace(/\D/g, '')
    setRemoving(true)
    setRemoveError('')
    try {
      const res = await fetch(`${PUBLIC_API_URL}/public/register/${qrToken}/signature`, {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ cpf: digits, email: email.trim() }),
      })
      if (!res.ok) throw new Error(`HTTP ${res.status}`)
      // Depois de remover, a prévia consultada de novo devolve 'none' e o card volta ao estado A.
      preview.refetch()
    } catch {
      setRemoveError('Não foi possível remover a assinatura. Tente de novo.')
    } finally {
      setRemoving(false)
    }
  }

  const savedDate = preview.updatedAt ? formatDate(preview.updatedAt) : ''

  return (
    <section className={styles.card} aria-labelledby="signature-card-title">
      <header className={styles.head}>
        <h3 id="signature-card-title" className={styles.title}>Assinatura</h3>
        <span className={styles.badge}>Recomendado</span>
      </header>
      <p className={styles.hint}>Sua assinatura aparecerá no seu certificado.</p>

      {mode === 'A' && (
        <button type="button" className={styles.empty} onClick={() => setModalOpen(true)}>
          ✍️ Toque para assinar
        </button>
      )}

      {mode === 'loading' && (
        <div className={styles.skeleton} role="status" aria-label="Carregando assinatura" />
      )}

      {mode === 'B' && preview.previewUrl && (
        <>
          <div className={styles.previewBox}>
            {/* eslint-disable-next-line @next/next/no-img-element -- URL assinada temporária, não passa pelo otimizador */}
            <img
              src={preview.previewUrl}
              alt="Assinatura salva"
              className={styles.previewImg}
              onError={() => preview.refetch()}
            />
          </div>
          {savedDate && <p className={styles.meta}>Assinatura salva em {savedDate}</p>}
          <div className={styles.options}>
            <span className={styles.optionSelected} aria-current="true">
              <Check size={16} aria-hidden="true" /> Usar esta
            </span>
            <button type="button" className={styles.optionBtn} onClick={() => setModalOpen(true)}>
              <RotateCcw size={16} aria-hidden="true" /> Assinar novamente
            </button>
          </div>
          <button
            type="button"
            className={styles.linkBtn}
            onClick={removeSaved}
            disabled={removing}
          >
            Remover assinatura salva
          </button>
        </>
      )}

      {mode === 'C' && draft && (
        <>
          <div className={styles.previewBox}>
            {/* eslint-disable-next-line @next/next/no-img-element -- objectURL local */}
            <img src={draft.previewUrl} alt="Nova assinatura" className={styles.previewImg} />
            <span className={styles.newBadge}>Nova</span>
          </div>
          <div className={styles.options}>
            <button type="button" className={styles.optionBtn} onClick={() => setModalOpen(true)}>
              <RotateCcw size={16} aria-hidden="true" /> Refazer
            </button>
            <button type="button" className={styles.optionBtn} onClick={removeDraft}>
              <Trash2 size={16} aria-hidden="true" /> Remover
            </button>
          </div>
        </>
      )}

      {mode === 'D' && (
        <div className={styles.locked}>
          <PenLine className={styles.lockedIcon} size={22} aria-hidden="true" />
          <p className={styles.lockedText}>
            Este CPF já tem uma assinatura salva, que será usada no seu certificado.
          </p>
        </div>
      )}

      {removeError && <p className={styles.error} role="alert">{removeError}</p>}

      <SignatureModal open={modalOpen} onCancel={closeModal} onConfirm={handleConfirm} />
    </section>
  )
}
