'use client'

import { useCallback, useEffect, useState } from 'react'
import type { SignaturePreviewResponse } from '@simtc/shared-types'
import { validateCpf } from '@/lib/validate-cpf'

export const PUBLIC_API_URL = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3001/api'

const DEBOUNCE_MS = 600
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

export function isValidEmail(email: string): boolean {
  return EMAIL_RE.test(email.trim())
}

export type SignaturePreviewState = 'idle' | 'loading' | 'none' | 'found' | 'locked' | 'error'

export interface SignaturePreview {
  state: SignaturePreviewState
  /** Signed URL de 120 s. Só existe quando state === 'found'. */
  previewUrl?: string
  updatedAt?: string
  /** Refaz a consulta (ex.: a signed URL expirou ou a assinatura foi removida). */
  refetch(): void
}

interface Result {
  state: SignaturePreviewState
  previewUrl?: string
  updatedAt?: string
}

/**
 * Consulta a prévia da assinatura salva para o CPF + e-mail digitados.
 * - Só dispara com CPF válido e e-mail com formato válido.
 * - Debounce de 600 ms; cada mudança de entrada cancela a requisição anterior
 *   (AbortController), então respostas atrasadas são descartadas.
 * - Erro de rede ou HTTP cai em 'error', que o card trata como vazio (estado A).
 */
export function useSignaturePreview(qrToken: string, cpf: string, email: string): SignaturePreview {
  const [result, setResult] = useState<Result>({ state: 'idle' })
  const [tick, setTick] = useState(0)

  const digits = cpf.replace(/\D/g, '')
  const mail = email.trim()

  useEffect(() => {
    if (!validateCpf(digits) || !isValidEmail(mail)) {
      setResult({ state: 'idle' })
      return
    }

    setResult({ state: 'loading' })
    const controller = new AbortController()

    const timer = setTimeout(async () => {
      try {
        const res = await fetch(`${PUBLIC_API_URL}/public/register/${qrToken}/signature-preview`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ cpf: digits, email: mail }),
          signal: controller.signal,
        })
        if (!res.ok) throw new Error(`HTTP ${res.status}`)
        const data = (await res.json()) as SignaturePreviewResponse
        if (controller.signal.aborted) return
        if (data.status === 'found') {
          setResult({ state: 'found', previewUrl: data.previewUrl, updatedAt: data.updatedAt })
        } else {
          setResult({ state: data.status })
        }
      } catch {
        if (controller.signal.aborted) return
        setResult({ state: 'error' })
      }
    }, DEBOUNCE_MS)

    return () => {
      clearTimeout(timer)
      controller.abort()
    }
  }, [qrToken, digits, mail, tick])

  const refetch = useCallback(() => setTick((t) => t + 1), [])

  return { ...result, refetch }
}
