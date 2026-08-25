'use client'

import { useState } from 'react'
import Link from 'next/link'
import { Loader2, ArrowLeft } from 'lucide-react'
import Image from 'next/image'
import { forgotPasswordAction } from '@/app/actions/auth'
import styles from './forgot-password.module.css'

export default function ForgotPasswordPage() {
  const [email, setEmail] = useState('')
  const [isLoading, setIsLoading] = useState(false)
  const [submitted, setSubmitted] = useState(false)
  const [error, setError] = useState('')

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError('')

    if (!email) {
      setError('Informe seu e-mail para continuar.')
      return
    }

    setIsLoading(true)
    const result = await forgotPasswordAction(email)
    setIsLoading(false)

    if (result.error) {
      setError(result.error)
      return
    }

    setSubmitted(true)
  }

  return (
    <div className={styles.page}>

      {/* ── Painel esquerdo: logo ─────────────────────────────── */}
      <div className={styles.leftPanel}>
        <div className={styles.brandArea}>
          <Image
            className={styles.logo}
            src="/logo-simtc.png"
            alt="SIM Treinamentos"
            width={500}
            height={500}
            priority
            style={{ objectFit: 'contain' }}
          />
          <p className={styles.tagline}>
            Sistema de Automação de Treinamentos
          </p>
        </div>
      </div>

      {/* ── Painel direito: formulário ────────────────────────── */}
      <div className={styles.rightPanel}>
        <div className={styles.formContainer}>

          {/* Logo — visível só em mobile */}
          <div className={styles.mobileBrand}>
            <Image
              src="/logo-simtc.png"
              alt="SIM Treinamentos"
              width={140}
              height={140}
              priority
              className={styles.mobileLogo}
            />
          </div>

          {/* Cabeçalho */}
          <div className={styles.heading}>
            <h1>Recuperar senha</h1>
            <p>
              {submitted
                ? 'Verifique sua caixa de entrada.'
                : 'Informe o e-mail da sua conta para receber o link de redefinição.'}
            </p>
          </div>

          {!submitted ? (
            <form onSubmit={handleSubmit} className={styles.form}>
              <div className={styles.field}>
                <label htmlFor="email" className={styles.label}>
                  E-mail
                </label>
                <input
                  id="email"
                  type="email"
                  autoComplete="username"
                  autoFocus
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="seu@email.com"
                  className={styles.input}
                  disabled={isLoading}
                />
              </div>

              <div className={styles.formRow}>
                <Link href="/login" className={styles.backLink}>
                  <ArrowLeft size={14} /> Voltar ao login
                </Link>
                <button type="submit" disabled={isLoading} className={styles.submitBtn}>
                  {isLoading && <Loader2 size={16} className={styles.spinner} />}
                  {isLoading ? 'Enviando…' : 'Enviar link'}
                </button>
              </div>

              {error && <p className={styles.errorMsg}>{error}</p>}
            </form>
          ) : (
            <div className={styles.successBox}>
              <p className={styles.successMsg}>
                Se o e-mail <strong>{email}</strong> estiver cadastrado, você receberá um link para redefinir sua senha em breve.
              </p>
              <Link href="/login" className={styles.backLink}>
                <ArrowLeft size={14} /> Voltar ao login
              </Link>
            </div>
          )}

        </div>
      </div>
    </div>
  )
}
