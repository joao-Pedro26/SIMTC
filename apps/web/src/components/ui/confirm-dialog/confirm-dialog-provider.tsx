'use client'

import { createContext, useCallback, useContext, useRef, useState } from 'react'
import { AlertTriangle, X } from 'lucide-react'
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

/** Resposta do aviso de alterações não salvas: salvar, descartar ou continuar editando. */
export type UnsavedChoice = 'save' | 'discard' | 'cancel'
type UnsavedFn = () => Promise<UnsavedChoice>

const ConfirmContext = createContext<ConfirmFn | null>(null)
const UnsavedContext = createContext<UnsavedFn | null>(null)

/**
 * Pergunta o que fazer com alterações não salvas (ex.: ao fechar um drawer).
 * Sem o provider, devolve 'discard' para não travar quem fecha a tela.
 */
export function useConfirmUnsaved(): UnsavedFn {
  const ctx = useContext(UnsavedContext)
  return ctx ?? (() => Promise.resolve('discard' as UnsavedChoice))
}

export function useConfirm(): ConfirmFn {
  const ctx = useContext(ConfirmContext)
  if (!ctx) throw new Error('useConfirm deve ser usado dentro de ConfirmDialogProvider')
  return ctx
}

// ── Provider ──────────────────────────────────────────────────────────────

export function ConfirmDialogProvider({ children }: { children: React.ReactNode }) {
  const [dialog, setDialog] = useState<DialogState | null>(null)
  const [unsaved, setUnsaved] = useState<{ resolve: (c: UnsavedChoice) => void } | null>(null)
  const overlayRef = useRef<HTMLDivElement>(null)

  const confirm = useCallback((options: ConfirmOptions): Promise<boolean> => {
    return new Promise((resolve) => {
      setDialog({ ...options, resolve })
    })
  }, [])

  const confirmUnsaved = useCallback((): Promise<UnsavedChoice> => {
    return new Promise((resolve) => setUnsaved({ resolve }))
  }, [])

  function answerUnsaved(choice: UnsavedChoice) {
    unsaved?.resolve(choice)
    setUnsaved(null)
  }

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
     <UnsavedContext.Provider value={confirmUnsaved}>
      {children}

      {unsaved && (
        <div
          className={styles.overlay}
          onClick={(e) => { if (e.target === e.currentTarget) answerUnsaved('cancel') }}
          onKeyDown={(e) => { if (e.key === 'Escape') answerUnsaved('cancel') }}
          role="dialog"
          aria-modal="true"
          aria-labelledby="unsaved-title"
          aria-describedby="unsaved-message"
        >
          <div className={`${styles.dialog} ${styles.dialogWithClose}`}>
            <button
              className={styles.closeBtn}
              onClick={() => answerUnsaved('cancel')}
              aria-label="Continuar editando"
              title="Continuar editando"
            >
              <X size={16} />
            </button>
            <h2 id="unsaved-title" className={styles.title}>Alterações não salvas</h2>
            <p id="unsaved-message" className={styles.message}>
              Você fez alterações que ainda não foram salvas. Deseja salvar antes de sair?
            </p>
            <div className={styles.actions}>
              <button className={styles.cancelBtn} onClick={() => answerUnsaved('discard')}>
                Descartar
              </button>
              <button
                className={`${styles.confirmBtn} ${styles.btnPrimary}`}
                onClick={() => answerUnsaved('save')}
                autoFocus
              >
                Salvar
              </button>
            </div>
          </div>
        </div>
      )}

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
     </UnsavedContext.Provider>
    </ConfirmContext.Provider>
  )
}
