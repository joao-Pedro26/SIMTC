'use client'

import { useState, Suspense } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import Link from 'next/link'
import { Eye, EyeOff, Loader2, ArrowLeft } from 'lucide-react'
import Image from 'next/image'
import { resetPasswordAction } from '@/app/actions/auth'
import styles from './reset-password.module.css'

function ResetPasswordForm() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const token = searchParams.get('token') ?? ''

  const [newPassword, setNewPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [showConfirm, setShowConfirm] = useState(false)
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState('')

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError('')

    if (!newPassword) {
      setError('Informe a nova senha.')
      return
    }

    if (newPassword.length < 8) {
      setError('A senha deve ter no mínimo 8 caracteres.')
      return
    }

    if (newPassword !== confirmPassword) {
      setError('As senhas não coincidem.')
      return
    }

    if (!token) {
      setError('Link de redefinição inválido. Solicite um novo link.')
      return
    }

    setIsLoading(true)
    const result = await resetPasswordAction(token, newPassword)
    setIsLoading(false)

    if (result.error) {
      setError(result.error)
      return
    }

    router.push('/login?reset=success')
  }

  return (
    <form onSubmit={handleSubmit} className={styles.form}>
      <div className={styles.field}>
        <label htmlFor="newPassword" className={styles.label}>
          Nova senha
        </label>
        <div className={styles.passwordWrapper}>
          <input
            id="newPassword"
            type={showPassword ? 'text' : 'password'}
            autoComplete="new-password"
            autoFocus
            value={newPassword}
            onChange={(e) => setNewPassword(e.target.value)}
            placeholder="Mínimo 8 caracteres"
            className={styles.input}
            disabled={isLoading}
          />
          <button
            type="button"
            onClick={() => setShowPassword((v) => !v)}
            className={styles.eyeBtn}
            tabIndex={-1}
          >
            {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
          </button>
        </div>
      </div>

      <div className={styles.field}>
        <label htmlFor="confirmPassword" className={styles.label}>
          Confirmar senha
        </label>
        <div className={styles.passwordWrapper}>
          <input
            id="confirmPassword"
            type={showConfirm ? 'text' : 'password'}
            autoComplete="new-password"
            value={confirmPassword}
            onChange={(e) => setConfirmPassword(e.target.value)}
            placeholder="Repita a nova senha"
            className={styles.input}
            disabled={isLoading}
          />
          <button
            type="button"
            onClick={() => setShowConfirm((v) => !v)}
            className={styles.eyeBtn}
            tabIndex={-1}
          >
            {showConfirm ? <EyeOff size={18} /> : <Eye size={18} />}
          </button>
        </div>
      </div>

      <div className={styles.formRow}>
        <Link href="/login" className={styles.backLink}>
          <ArrowLeft size={14} /> Voltar ao login
        </Link>
        <button type="submit" disabled={isLoading} className={styles.submitBtn}>
          {isLoading && <Loader2 size={16} className={styles.spinner} />}
          {isLoading ? 'Salvando…' : 'Redefinir senha'}
        </button>
      </div>

      {error && <p className={styles.errorMsg}>{error}</p>}
    </form>
  )
}

export default function ResetPasswordPage() {
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
            <h1>Redefinir senha</h1>
            <p>Escolha uma nova senha para a sua conta.</p>
          </div>

          <Suspense fallback={null}>
            <ResetPasswordForm />
          </Suspense>

        </div>
      </div>
    </div>
  )
}
