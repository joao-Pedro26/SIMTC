'use client'

import { useState } from 'react'
import Image from 'next/image'
import styles from './public-register.module.css'

const API_URL = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3001/api'

type Screen = 'confirm' | 'form' | 'success'

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
  participationType: 'SOMENTE_TEORICA' | 'TEORICA_E_PRATICA' | ''
}

const CNH_CATEGORIES = ['A', 'B', 'AB', 'C', 'D', 'E'] as const

function validateCpf(cpf: string): boolean {
  const digits = cpf.replace(/\D/g, '')
  if (digits.length !== 11 || /^(\d)\1{10}$/.test(digits)) return false
  let sum = 0
  for (let i = 0; i < 9; i++) sum += Number(digits[i]) * (10 - i)
  let check = (sum * 10) % 11
  if (check === 10 || check === 11) check = 0
  if (check !== Number(digits[9])) return false
  sum = 0
  for (let i = 0; i < 10; i++) sum += Number(digits[i]) * (11 - i)
  check = (sum * 10) % 11
  if (check === 10 || check === 11) check = 0
  return check === Number(digits[10])
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
  participationType: '',
}

export function PublicRegisterFlow({ companyName, companyLogoUrl, courseName, qrToken }: Props) {
  const [screen, setScreen] = useState<Screen>('confirm')
  const [form, setForm] = useState<FormState>(emptyForm)
  const [submitting, setSubmitting] = useState(false)
  const [errorMsg, setErrorMsg] = useState('')
  const [cpfInvalid, setCpfInvalid] = useState(false)
  // Key para re-montar a tela de sucesso e re-disparar animações
  const [successKey, setSuccessKey] = useState(0)

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
    const rawCpf = form.cpf.replace(/\D/g, '')

    setCpfInvalid(false)
    setErrorMsg('')

    if (!form.name.trim() || !form.cpf || !form.email.trim() || !form.cnhCategory || !form.cnhExpiration || !form.participationType) {
      setErrorMsg('Preencha todos os campos para continuar.')
      return
    }
    if (!validateCpf(rawCpf)) {
      setCpfInvalid(true)
      setErrorMsg('CPF inválido — verifique os dígitos.')
      return
    }

    setSubmitting(true)
    try {
      const res = await fetch(`${API_URL}/public/register/${qrToken}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: form.name.trim(),
          cpf: rawCpf,
          email: form.email.trim(),
          cnhCategory: form.cnhCategory,
          cnhExpiration: form.cnhExpiration,
          participationType: form.participationType,
        }),
      })
      if (!res.ok) {
        const body = await res.json().catch(() => ({}))
        throw new Error(body.message ?? 'Erro ao realizar inscrição.')
      }
      setSuccessKey((k) => k + 1)
      setScreen('success')
    } catch (e) {
      setErrorMsg(e instanceof Error ? e.message : 'Erro ao realizar inscrição.')
    } finally {
      setSubmitting(false)
    }
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

              {/* 03 — Tipo de participação */}
              <p className={styles.sectionLabel}>
                <span className={styles.slNum}>03</span> Tipo de participação
              </p>

              <div className={styles.cnhSection}>
                <div className={styles.participationGrid}>
                  {([
                    { value: 'SOMENTE_TEORICA',   label: 'Teoria' },
                    { value: 'TEORICA_E_PRATICA',  label: 'Teoria + Prática' },
                  ] as const).map(({ value, label }) => (
                    <button
                      key={value}
                      type="button"
                      className={`${styles.cnhBtn}${form.participationType === value ? ` ${styles.cnhBtnActive}` : ''}`}
                      onClick={() => setField('participationType', value)}
                    >
                      {label}
                    </button>
                  ))}
                </div>
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
                disabled={submitting}
              >
                {submitting ? 'Enviando...' : 'Confirmar inscrição'}
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

                <p className={styles.successFootnote}>
                  Esta página pode ser fechada com segurança.
                </p>
              </div>
            </div>
          )}

        </div>
      </div>
    </>
  )
}
