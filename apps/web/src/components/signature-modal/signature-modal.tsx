'use client'

import { useEffect, useState } from 'react'
import { useSignaturePad } from '@/lib/signature/use-signature-pad'
import styles from './signature-modal.module.css'

interface SignatureModalProps {
  open: boolean
  onCancel: () => void
  /** Recebe o PNG recortado e uma URL de prévia (object URL); quem recebe é dono da URL e deve revogá-la. */
  onConfirm: (blob: Blob, previewUrl: string) => void
}

export function SignatureModal({ open, onCancel, onConfirm }: SignatureModalProps) {
  if (!open) return null
  return <SignatureModalContent onCancel={onCancel} onConfirm={onConfirm} />
}

function SignatureModalContent({ onCancel, onConfirm }: Omit<SignatureModalProps, 'open'>) {
  const { canvasRef, isEmpty, clear, toBlob, hasEnoughInk } = useSignaturePad()
  const [saving, setSaving] = useState(false)

  // Trava o scroll do body (position fixed é o que funciona no iOS Safari).
  useEffect(() => {
    const { body, documentElement } = document
    const scrollY = window.scrollY
    const previous = {
      position: body.style.position,
      top: body.style.top,
      width: body.style.width,
      overflow: body.style.overflow,
      htmlOverflow: documentElement.style.overflow,
    }

    body.style.position = 'fixed'
    body.style.top = `-${scrollY}px`
    body.style.width = '100%'
    body.style.overflow = 'hidden'
    documentElement.style.overflow = 'hidden'

    return () => {
      body.style.position = previous.position
      body.style.top = previous.top
      body.style.width = previous.width
      body.style.overflow = previous.overflow
      documentElement.style.overflow = previous.htmlOverflow
      window.scrollTo(0, scrollY)
    }
  }, [])

  useEffect(() => {
    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === 'Escape') onCancel()
    }
    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [onCancel])

  async function handleConfirm() {
    if (!hasEnoughInk || saving) return
    setSaving(true)
    try {
      const blob = await toBlob()
      if (blob) onConfirm(blob, URL.createObjectURL(blob))
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className={styles.overlay}>
      <div
        className={styles.dialog}
        role="dialog"
        aria-modal="true"
        aria-labelledby="signature-modal-title"
      >
        <header className={styles.header}>
          <h2 id="signature-modal-title" className={styles.title}>Sua assinatura</h2>
          <p className={styles.hint}>Gire o celular para ter mais espaço</p>
        </header>

        <div className={styles.canvasArea}>
          <canvas ref={canvasRef} className={styles.canvas} aria-label="Área para assinar" />
          <div className={styles.baseline} aria-hidden="true">
            <span className={styles.baselineLabel}>Assine acima da linha</span>
          </div>
        </div>

        <p className={styles.consent}>
          Ao confirmar, você autoriza o uso desta assinatura exclusivamente na emissão dos seus certificados da SIM Treinamentos.
        </p>

        <footer className={styles.actions}>
          <button type="button" className={styles.clearBtn} onClick={clear} disabled={isEmpty}>
            Limpar
          </button>
          <div className={styles.rightActions}>
            <button type="button" className={styles.cancelBtn} onClick={onCancel}>
              Cancelar
            </button>
            <button
              type="button"
              className={styles.confirmBtn}
              onClick={handleConfirm}
              disabled={!hasEnoughInk || saving}
            >
              Confirmar
            </button>
          </div>
        </footer>
      </div>
    </div>
  )
}
