'use client'

import { createContext, useCallback, useContext, useRef, useState } from 'react'
import { CheckCircle2, XCircle, AlertTriangle, Info, X } from 'lucide-react'
import styles from './toast.module.css'

// ── Types ────────────────────────────────────────────────────────────────────

type ToastType = 'success' | 'error' | 'warning' | 'info'

interface ToastItem {
  id: string
  type: ToastType
  message: string
  exiting?: boolean
}

interface ToastContextValue {
  success: (message: string) => void
  error: (message: string) => void
  warning: (message: string) => void
  info: (message: string) => void
}

const ToastContext = createContext<ToastContextValue | null>(null)

export function useToast() {
  const ctx = useContext(ToastContext)
  if (!ctx) throw new Error('useToast deve ser usado dentro de ToastProvider')
  return ctx
}

// ── Config ───────────────────────────────────────────────────────────────────

const DURATION: Record<ToastType, number> = {
  success: 3500,
  error:   5000,
  warning: 4000,
  info:    3500,
}

const ICON = {
  success: CheckCircle2,
  error:   XCircle,
  warning: AlertTriangle,
  info:    Info,
} as const

const ICON_CLASS: Record<ToastType, string> = {
  success: styles.iconSuccess,
  error:   styles.iconError,
  warning: styles.iconWarning,
  info:    styles.iconInfo,
}

const TOAST_CLASS: Record<ToastType, string> = {
  success: styles.success,
  error:   styles.error,
  warning: styles.warning,
  info:    styles.info,
}

// ── Provider ─────────────────────────────────────────────────────────────────

export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [toasts, setToasts] = useState<ToastItem[]>([])
  const timers = useRef<Map<string, ReturnType<typeof setTimeout>>>(new Map())

  const dismiss = useCallback((id: string) => {
    // mark exiting first for slide-out animation
    setToasts((prev) =>
      prev.map((t) => (t.id === id ? { ...t, exiting: true } : t))
    )
    // then remove after animation
    const removeTimer = setTimeout(() => {
      setToasts((prev) => prev.filter((t) => t.id !== id))
    }, 280)

    const autoTimer = timers.current.get(id)
    if (autoTimer) {
      clearTimeout(autoTimer)
      timers.current.delete(id)
    }
    timers.current.set(`remove-${id}`, removeTimer)
  }, [])

  const addToast = useCallback(
    (type: ToastType, message: string) => {
      const id = `${Date.now()}-${Math.random().toString(36).slice(2)}`
      setToasts((prev) => [...prev, { id, type, message }])
      const timer = setTimeout(() => dismiss(id), DURATION[type])
      timers.current.set(id, timer)
    },
    [dismiss]
  )

  const value: ToastContextValue = {
    success: (msg) => addToast('success', msg),
    error:   (msg) => addToast('error', msg),
    warning: (msg) => addToast('warning', msg),
    info:    (msg) => addToast('info', msg),
  }

  return (
    <ToastContext.Provider value={value}>
      {children}
      <div className={styles.container} aria-live="polite" aria-atomic="false">
        {toasts.map((toast) => {
          const Icon = ICON[toast.type]
          return (
            <div
              key={toast.id}
              role="status"
              className={`${styles.toast} ${TOAST_CLASS[toast.type]} ${toast.exiting ? styles.exiting : ''}`}
            >
              <Icon size={17} className={`${styles.icon} ${ICON_CLASS[toast.type]}`} />
              <span className={styles.message}>{toast.message}</span>
              <button
                className={styles.closeBtn}
                onClick={() => dismiss(toast.id)}
                aria-label="Fechar notificação"
              >
                <X size={13} />
              </button>
            </div>
          )
        })}
      </div>
    </ToastContext.Provider>
  )
}
