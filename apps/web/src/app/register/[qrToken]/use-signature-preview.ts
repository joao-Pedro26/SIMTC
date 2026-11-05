'use client'

import { useCallback, useEffect, useState } from 'react'
import type { SignaturePreviewResponse } from '@simtc/shared-types'
import { validateCpf } from '@/lib/validate-cpf'

export const PUBLIC_API_URL = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3001/api'

const DEBOUNCE_MS = 600
/** Tempo máximo da consulta da prévia; depois disso o card cai em A e o envio segue liberado. */
const REQUEST_TIMEOUT_MS = 8000
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
  /** Chave (CPF normalizado + e-mail aparado) a que este resultado pertence. */
  key: string
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
  const [result, setResult] = useState<Result>({ key: '', state: 'idle' })
  const [tick, setTick] = useState(0)

  const digits = cpf.replace(/\D/g, '')
  const mail = email.trim()
  const key = `${digits}|${mail}`
  const valid = validateCpf(digits) && isValidEmail(mail)

  useEffect(() => {
    if (!valid) {
      setResult({ key, state: 'idle' })
      return
    }

    setResult({ key, state: 'loading' })
    const controller = new AbortController()
    // Timeout próprio: a prévia é opcional, então uma consulta travada vira 'error' (card em A)
    let requestTimeout: ReturnType<typeof setTimeout> | undefined
    let timedOut = false

    const timer = setTimeout(async () => {
      try {
        requestTimeout = setTimeout(() => {
          timedOut = true
          controller.abort()
        }, REQUEST_TIMEOUT_MS)
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
          setResult({ key, state: 'found', previewUrl: data.previewUrl, updatedAt: data.updatedAt })
        } else {
          setResult({ key, state: data.status })
        }
      } catch {
        // Timeout vira erro; abort por cleanup (CPF/e-mail mudou ou desmontou) é descartado em silêncio
        if (timedOut) setResult({ key, state: 'error' })
        else if (!controller.signal.aborted) setResult({ key, state: 'error' })
      } finally {
        clearTimeout(requestTimeout)
      }
    }, DEBOUNCE_MS)

    return () => {
      clearTimeout(timer)
      clearTimeout(requestTimeout)
      controller.abort()
    }
  }, [qrToken, digits, mail, key, valid, tick])

  const refetch = useCallback(() => setTick((t) => t + 1), [])

  // Resultado de outra chave (CPF/e-mail acabaram de mudar) nunca vaza: vira loading,
  // ou idle se os valores atuais não forem válidos. Assim o 'keep' antigo não é emitido.
  if (!valid) return { state: 'idle', refetch }
  if (result.key !== key) return { state: 'loading', refetch }
  return { state: result.state, previewUrl: result.previewUrl, updatedAt: result.updatedAt, refetch }
}
