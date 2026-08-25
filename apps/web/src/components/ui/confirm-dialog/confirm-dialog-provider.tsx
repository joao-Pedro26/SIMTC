'use client'

import { createContext, useCallback, useContext, useRef, useState } from 'react'
import { AlertTriangle } from 'lucide-react'
import styles from './confirm-dialog.module.css'

// ── Types ─────────────────────────────────────────────────────────────────

export interface ConfirmOptions {
  title: string
  message: string
  confirmLabel?: string
  cancelLabel?: string
  variant?: 'danger' | 'default'
}

interface DialogState extends ConfirmOptions {
  resolve: (value: boolean) => void
}

type ConfirmFn = (options: ConfirmOptions) => Promise<boolean>

const ConfirmContext = createContext<ConfirmFn | null>(null)

export function useConfirm(): ConfirmFn {
  const ctx = useContext(ConfirmContext)
  if (!ctx) throw new Error('useConfirm deve ser usado dentro de ConfirmDialogProvider')
  return ctx
}

// ── Provider ──────────────────────────────────────────────────────────────

export function ConfirmDialogProvider({ children }: { children: React.ReactNode }) {
  const [dialog, setDialog] = useState<DialogState | null>(null)
  const overlayRef = useRef<HTMLDivElement>(null)

  const confirm = useCallback((options: ConfirmOptions): Promise<boolean> => {
    return new Promise((resolve) => {
      setDialog({ ...options, resolve })
    })
  }, [])

  function handleConfirm() {
    dialog?.resolve(true)
    setDialog(null)
  }

  function handleCancel() {
    dialog?.resolve(false)
    setDialog(null)
  }

  function handleOverlayClick(e: React.MouseEvent<HTMLDivElement>) {
    if (e.target === overlayRef.current) handleCancel()
  }

  function handleKeyDown(e: React.KeyboardEvent) {
    if (e.key === 'Escape') handleCancel()
    if (e.key === 'Enter') handleConfirm()
  }

  const isDanger = dialog?.variant === 'danger'

  return (
    <ConfirmContext.Provider value={confirm}>
      {children}

      {dialog && (
        <div
          ref={overlayRef}
          className={styles.overlay}
          onClick={handleOverlayClick}
          onKeyDown={handleKeyDown}
          role="dialog"
          aria-modal="true"
          aria-labelledby="confirm-title"
          aria-describedby="confirm-message"
        >
          <div className={`${styles.dialog} ${isDanger ? styles.dialogDanger : ''}`}>

            {isDanger && (
              <div className={styles.iconRing}>
                <AlertTriangle size={20} className={styles.dangerIcon} strokeWidth={2} />
              </div>
            )}

            <h2 id="confirm-title" className={styles.title}>
              {dialog.title}
            </h2>
            <p id="confirm-message" className={styles.message}>
              {dialog.message}
            </p>

            <div className={styles.actions}>
              <button className={styles.cancelBtn} onClick={handleCancel}>
                {dialog.cancelLabel ?? 'Cancelar'}
              </button>
              <button
                className={`${styles.confirmBtn} ${isDanger ? styles.btnDanger : styles.btnPrimary}`}
                onClick={handleConfirm}
                autoFocus
              >
                {dialog.confirmLabel ?? 'Confirmar'}
              </button>
            </div>

          </div>
        </div>
      )}
    </ConfirmContext.Provider>
  )
}
