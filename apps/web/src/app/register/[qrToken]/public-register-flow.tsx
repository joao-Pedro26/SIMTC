'use client'

import { useEffect, useRef, useState } from 'react'
import Image from 'next/image'
import type { RegisterParticipantPublicResponse, SignatureAction } from '@simtc/shared-types'
import { validateCpf } from '@/lib/validate-cpf'
import {
  SignatureCard,
  type SignatureCardHandle,
  type SignatureCardState,
  type SignatureValue,
} from './signature-card'
import styles from './public-register.module.css'

const API_URL = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3001/api'

type Screen = 'confirm' | 'form' | 'success'

/** Resultado da assinatura mostrado na tela de sucesso. */
type SignatureOutcome = 'saved' | 'ignored' | 'none'

interface Props {
  companyName: string
  companyLogoUrl: string | null
  courseName: string
  qrToken: string
}

interface FormState {
  name: string
  cpf: string
  email: string
  cnhCategory: string
  cnhExpiration: string
}

const CNH_CATEGORIES = ['A', 'B', 'C', 'D', 'E', 'AB', 'AC', 'AD', 'AE'] as const

function outcomeOf(
  sent: SignatureAction,
  cardState: SignatureCardState,
  res: Partial<RegisterParticipantPublicResponse>,
): SignatureOutcome {
  if (res.signatureSaved) return 'saved'
  if (sent === 'replace' || res.signatureIgnored) return 'ignored'
  // 'keep' só é enviado com assinatura salva (estado B), que continua valendo
  if (sent === 'keep') return 'saved'
  // D: CPF já tem assinatura salva (e-mail não confere); o backend mantém a antiga
  if (cardState === 'D') return 'saved'
  return 'none'
}

function applyCpfMask(value: string): string {
  const d = value.replace(/\D/g, '').slice(0, 11)
  if (d.length <= 3) return d
  if (d.length <= 6) return `${d.slice(0, 3)}.${d.slice(3)}`
  if (d.length <= 9) return `${d.slice(0, 3)}.${d.slice(3, 6)}.${d.slice(6)}`
  return `${d.slice(0, 3)}.${d.slice(3, 6)}.${d.slice(6, 9)}-${d.slice(9)}`
}

const emptyForm: FormState = {
  name: '',
  cpf: '',
  email: '',
  cnhCategory: '',
  cnhExpiration: '',
}

export function PublicRegisterFlow({ companyName, companyLogoUrl, courseName, qrToken }: Props) {
  const [screen, setScreen] = useState<Screen>('confirm')
  const [form, setForm] = useState<FormState>(emptyForm)
  const [submitting, setSubmitting] = useState(false)
  const [errorMsg, setErrorMsg] = useState('')
  const [cpfInvalid, setCpfInvalid] = useState(false)
  // Key para re-montar a tela de sucesso e re-disparar animações
  const [successKey, setSuccessKey] = useState(0)
  // Valor do card de assinatura (ação, blob e estado A/B/C/D)
  const [sig, setSig] = useState<SignatureValue>({ action: 'none', cardState: 'loading' })
  const [outcome, setOutcome] = useState<SignatureOutcome>('none')
  const [reminderOpen, setReminderOpen] = useState(false)
  // Lembrete aparece uma vez por página; a ref não causa re-render
  const reminderShownRef = useRef(false)
  const cardRef = useRef<SignatureCardHandle>(null)
  const reminderPrimaryRef = useRef<HTMLButtonElement>(null)

  useEffect(() => {
    if (reminderOpen) reminderPrimaryRef.current?.focus()
  }, [reminderOpen])

  function setField(field: keyof FormState, value: string) {
    setForm((prev) => ({ ...prev, [field]: value }))
  }

  function goToForm() {
    setErrorMsg('')
    setCpfInvalid(false)
    setScreen('form')
  }

  function goBack() {
    setErrorMsg('')
    setCpfInvalid(false)
    setScreen('confirm')
  }

  async function handleSubmit() {
    // Com a prévia em consulta o envio é bloqueado: o botão fica disabled, e esta guarda cobre outros caminhos
    if (sig.cardState === 'loading') return

    const rawCpf = form.cpf.replace(/\D/g, '')

    setCpfInvalid(false)
    setErrorMsg('')

    if (!form.name.trim() || !form.cpf || !form.email.trim() || !form.cnhCategory || !form.cnhExpiration) {
      setErrorMsg('Preencha todos os campos para continuar.')
      return
    }
    if (!validateCpf(rawCpf)) {
      setCpfInvalid(true)
      setErrorMsg('CPF inválido — verifique os dígitos.')
      return
    }

    // Lembrete de assinatura: uma vez por página, só com o card vazio (estado A)
    if (sig.cardState === 'A' && !reminderShownRef.current) {
      reminderShownRef.current = true
      setReminderOpen(true)
      return
    }

    await submitRegistration()
  }

  async function submitRegistration() {
    const sentAction = sig.action
    const sentCardState = sig.cardState
    const fields: Record<string, string> = {
      name: form.name.trim(),
      cpf: form.cpf.replace(/\D/g, ''),
      email: form.email.trim(),
      cnhCategory: form.cnhCategory,
      cnhExpiration: form.cnhExpiration,
      signatureAction: sentAction,
    }
    // Campos vazios são omitidos: o backend responde 400 para string vazia
    const present = Object.entries(fields).filter(([, value]) => value !== '')

    let init: RequestInit
    if (sig.blob) {
      // Multipart: não definir Content-Type à mão, o browser coloca o boundary
      const data = new FormData()
      for (const [key, value] of present) data.append(key, value)
      data.append('signature', new File([sig.blob], 'assinatura.png', { type: 'image/png' }))
      init = { method: 'POST', body: data }
    } else {
      init = {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(Object.fromEntries(present)),
      }
    }

    setSubmitting(true)
    try {
      const res = await fetch(`${API_URL}/public/register/${qrToken}`, init)
      if (!res.ok) {
        const body = await res.json().catch(() => ({}))
        throw new Error(body.message ?? 'Erro ao realizar inscrição.')
      }
      const result: Partial<RegisterParticipantPublicResponse> = await res.json().catch(() => ({}))
      setOutcome(outcomeOf(sentAction, sentCardState, result))
      setSuccessKey((k) => k + 1)
      setScreen('success')
    } catch (e) {
      setErrorMsg(e instanceof Error ? e.message : 'Erro ao realizar inscrição.')
    } finally {
      setSubmitting(false)
    }
  }

  function signNowFromReminder() {
    setReminderOpen(false)
    cardRef.current?.openModal()
  }

  function sendWithoutSignatureFromReminder() {
    setReminderOpen(false)
    void submitRegistration()
  }

  return (
    <>
      {/* ── Hero ─────────────────────────────────────────────── */}
      <div className={styles.hero}>
        <h1 className={styles.heroTitle}>{courseName}</h1>
      </div>

      {/* ── Barra de logos ───────────────────────────────────── */}
      <div className={styles.logosBar}>
        <div className={styles.logosInner}>
          <Image
            src="/logo-simtc.png"
            alt="SIM Treinamentos"
            width={60}
            height={60}
            className={styles.simLogoImg}
          />
          <span className={styles.logosSep}>+</span>
          {companyLogoUrl ? (
            <Image
              src={companyLogoUrl}
              alt={companyName}
              width={60}
              height={60}
              className={styles.companyLogoImg}
            />
          ) : (
            <div className={styles.logoFallback} aria-label={companyName}>
              {companyName.slice(0, 2).toUpperCase()}
            </div>
          )}
        </div>
      </div>

      {/* ── Conteúdo ─────────────────────────────────────────── */}
      <div className={styles.pageContent}>
        <div className={styles.inner}>

          {/* ① Confirmar */}
          {screen === 'confirm' && (
            <div className={styles.screen}>
              <div className={styles.noticeBlock}>
                <p className={styles.nbLabel}>Aviso de treinamento</p>
                <p className={styles.nbCourse}>{courseName}</p>
                <p className={styles.nbCompany}>{companyName}</p>
                <div className={styles.nbDivider} />
                <div className={styles.nbStatus}>
                  <div className={styles.nbStatusDot} />
                  Inscrições abertas
                </div>
              </div>

              <button className={styles.btnCta} onClick={goToForm}>
                Realizar inscrição
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
                  <line x1="5" y1="12" x2="19" y2="12" />
                  <polyline points="13 6 19 12 13 18" />
                </svg>
              </button>
            </div>
          )}

          {/* ② Formulário */}
          {screen === 'form' && (
            <div className={styles.screen}>
              <div className={styles.progressTrack}>
                <div className={styles.progressFill} />
              </div>

              {/* 01 — Identificação */}
              <p className={styles.sectionLabel}>
                <span className={styles.slNum}>01</span> Identificação
              </p>

              <div className={styles.fieldStack}>
                <div className={styles.flWrap}>
                  <input
                    className={styles.flInput}
                    type="text"
                    id="reg-name"
                    placeholder=" "
                    autoComplete="name"
                    value={form.name}
                    onChange={(e) => setField('name', e.target.value)}
                  />
                  <label className={styles.flLabel} htmlFor="reg-name">
                    Nome completo
                  </label>
                </div>

                <div className={styles.flWrap}>
                  <input
                    className={`${styles.flInput}${cpfInvalid ? ` ${styles.invalid}` : ''}`}
                    type="text"
                    id="reg-cpf"
                    placeholder=" "
                    inputMode="numeric"
                    value={form.cpf}
                    onChange={(e) => {
                      setCpfInvalid(false)
                      setField('cpf', applyCpfMask(e.target.value))
                    }}
                  />
                  <label className={styles.flLabel} htmlFor="reg-cpf">
                    CPF
                  </label>
                </div>

                <div className={styles.flWrap}>
                  <input
                    className={styles.flInput}
                    type="email"
                    id="reg-email"
                    placeholder=" "
                    autoComplete="email"
                    value={form.email}
                    onChange={(e) => setField('email', e.target.value)}
                  />
                  <label className={styles.flLabel} htmlFor="reg-email">
                    E-mail
                  </label>
                </div>
              </div>

              {/* 02 — CNH */}
              <p className={styles.sectionLabel}>
                <span className={styles.slNum}>02</span> Habilitação (CNH)
              </p>

              <div className={styles.cnhSection}>
                <div className={styles.cnhGrid}>
                  {CNH_CATEGORIES.map((cat) => (
                    <button
                      key={cat}
                      type="button"
                      className={`${styles.cnhBtn}${form.cnhCategory === cat ? ` ${styles.cnhBtnActive}` : ''}`}
                      onClick={() => setField('cnhCategory', cat)}
                    >
                      {cat}
                    </button>
                  ))}
                </div>
              </div>

              <div className={styles.fieldStack}>
                <div className={styles.flWrap}>
                  <input
                    className={styles.flInput}
                    type="date"
                    id="reg-date"
                    value={form.cnhExpiration}
                    onChange={(e) => setField('cnhExpiration', e.target.value)}
                  />
                  <label className={styles.flLabelDate} htmlFor="reg-date">
                    Vencimento da CNH
                  </label>
                </div>
              </div>

              {/* 03 — Assinatura */}
              <p className={styles.sectionLabel}>
                <span className={styles.slNum}>03</span> Assinatura{' '}
                <span className={styles.slOptional}>(Opcional)</span>
              </p>

              <div className={styles.sigSection}>
                <SignatureCard
                  ref={cardRef}
                  qrToken={qrToken}
                  cpf={form.cpf}
                  email={form.email}
                  onChange={setSig}
                />
              </div>

              {errorMsg && (
                <div className={styles.errBox}>
                  <svg className={styles.errIcon} width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="#DC2626" strokeWidth="2.5" strokeLinecap="round" aria-hidden>
                    <circle cx="12" cy="12" r="10" />
                    <line x1="12" y1="8" x2="12" y2="13" />
                    <circle cx="12" cy="16.5" r="0.5" fill="#DC2626" />
                  </svg>
                  <span>{errorMsg}</span>
                </div>
              )}

              <button
                className={styles.btnCta}
                onClick={handleSubmit}
                disabled={submitting || sig.cardState === 'loading'}
              >
                {submitting
                  ? 'Enviando...'
                  : sig.cardState === 'loading'
                    ? 'Verificando assinatura...'
                    : 'Confirmar inscrição'}
              </button>

              <button className={styles.btnGhost} onClick={goBack}>
                ← Voltar
              </button>
            </div>
          )}

          {/* ③ Sucesso */}
          {screen === 'success' && (
            <div key={successKey} className={styles.screen}>
              <div className={styles.successWrap}>
                <div className={styles.successOrb}>
                  <svg width="44" height="44" viewBox="0 0 48 48" fill="none" aria-hidden>
                    <path
                      className={styles.checkPath}
                      d="M12 24 L20 32 L36 16"
                      stroke="#38BEC8"
                      strokeWidth="3.5"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                    />
                  </svg>
                </div>

                <p className={styles.successLabel}>Confirmado</p>
                <h2 className={styles.successTitle}>Inscrição realizada</h2>

                <div className={styles.successCards}>
                  <div className={styles.scCard}>
                    <div className={styles.scIcon}>
                      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#38BEC8" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
                        <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
                      </svg>
                    </div>
                    <div>
                      <p className={styles.scLabel}>Treinamento</p>
                      <p className={styles.scValue}>{courseName}</p>
                    </div>
                  </div>

                  <div className={styles.scCard}>
                    <div className={styles.scIcon}>
                      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#38BEC8" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
                        <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" />
                        <polyline points="9 22 9 12 15 12 15 22" />
                      </svg>
                    </div>
                    <div>
                      <p className={styles.scLabel}>Empresa</p>
                      <p className={styles.scValue}>{companyName}</p>
                    </div>
                  </div>
                </div>

                <p
                  className={`${styles.successSignature}${outcome === 'ignored' ? ` ${styles.sigWarn}` : ''}`}
                >
                  {outcome === 'saved' && '✓ Assinatura salva para o certificado.'}
                  {outcome === 'ignored' && 'Inscrição feita, mas a assinatura não pôde ser salva.'}
                  {outcome === 'none' && 'Você se inscreveu sem assinatura.'}
                </p>

                <p className={styles.successFootnote}>
                  Esta página pode ser fechada com segurança.
                </p>
              </div>
            </div>
          )}

        </div>
      </div>

      {/* ── Lembrete de assinatura (uma vez) ─────────────────── */}
      {reminderOpen && (
        <div className={styles.dialogBackdrop}>
          <div
            className={styles.dialog}
            role="dialog"
            aria-modal="true"
            aria-labelledby="reminder-title"
            onKeyDown={(e) => {
              if (e.key === 'Escape') setReminderOpen(false)
            }}
          >
            <h2 id="reminder-title" className={styles.dialogTitle}>Assinatura</h2>
            <p className={styles.dialogText}>
              Seu certificado sairá sem a sua assinatura. Deseja assinar agora?
            </p>
            <div className={styles.dialogActions}>
              <button
                ref={reminderPrimaryRef}
                type="button"
                className={styles.btnCta}
                onClick={signNowFromReminder}
              >
                Assinar agora
              </button>
              <button type="button" className={styles.btnGhost} onClick={sendWithoutSignatureFromReminder}>
                Enviar sem assinatura
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  )
}
