'use client'

import { useState, Suspense } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import Link from 'next/link'
import { Eye, EyeOff, Loader2, ArrowLeft } from 'lucide-react'
import Image from 'next/image'
import { loginAction, checkEmailAction, requestOtpAction, verifyOtpAction } from '@/app/actions/auth'
import styles from './login.module.css'

type Step = 'email' | 'password' | 'otp'

// Mesmo mapeamento usado no middleware — home de cada papel após o login
const ROLE_HOME: Record<string, string> = {
  ADMIN: '/dashboard',
  CONSULTANT: '/training-sessions',
  CLIENT: '/my-company',
}

function homeForRole(role?: string): string {
  return (role && ROLE_HOME[role]) || '/dashboard'
}

function PasswordResetBanner() {
  const searchParams = useSearchParams()
  if (searchParams.get('reset') !== 'success') return null
  return (
    <p style={{ fontSize: '0.875rem', color: '#15803d', background: '#f0fdf4', border: '1px solid #bbf7d0', padding: '0.75rem 1rem', borderRadius: 8, marginBottom: '1.5rem' }}>
      Senha redefinida com sucesso. Faça login com a nova senha.
    </p>
  )
}

export default function LoginPage() {
  const router = useRouter()

  const [step, setStep] = useState<Step>('email')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [otpCode, setOtpCode] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState('')
  const [info, setInfo] = useState('')

  function resetToEmailStep() {
    setStep('email')
    setPassword('')
    setOtpCode('')
    setError('')
    setInfo('')
  }

  async function handleEmailSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError('')

    if (!email) {
      setError('Informe seu e-mail para continuar.')
      return
    }

    setIsLoading(true)
    const result = await checkEmailAction(email)

    if (result.error) {
      setIsLoading(false)
      setError(result.error)
      return
    }

    if (result.authMethod === 'not_found') {
      setIsLoading(false)
      setError('E-mail não encontrado. Verifique e tente novamente.')
      return
    }

    if (result.authMethod === 'otp') {
      const otpResult = await requestOtpAction(email)
      setIsLoading(false)
      if (otpResult.error) {
        setError(otpResult.error)
        return
      }
      setInfo(`Enviamos um código de 6 dígitos para ${email}.`)
      setStep('otp')
      return
    }

    setIsLoading(false)
    setStep('password')
  }

  async function handlePasswordSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError('')

    if (!password) {
      setError('Informe sua senha para continuar.')
      return
    }

    setIsLoading(true)
    const result = await loginAction(email, password)
    setIsLoading(false)

    if (result.error) {
      setError(result.error)
      return
    }

    router.push(homeForRole(result.role))
  }

  async function handleOtpSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError('')

    if (otpCode.length !== 6) {
      setError('Informe o código de 6 dígitos enviado ao seu e-mail.')
      return
    }

    setIsLoading(true)
    const result = await verifyOtpAction(email, otpCode)
    setIsLoading(false)

    if (result.error) {
      setError(result.error)
      return
    }

    router.push(homeForRole(result.role))
  }

  async function handleResendOtp() {
    setError('')
    setIsLoading(true)
    const result = await requestOtpAction(email)
    setIsLoading(false)

    if (result.error) {
      setError(result.error)
      return
    }
    setInfo(`Reenviamos o código para ${email}.`)
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

          {/* Banner de sucesso ao redefinir senha */}
          <Suspense fallback={null}>
            <PasswordResetBanner />
          </Suspense>

          {/* Cabeçalho */}
          <div className={styles.heading}>
            <h1>Sistema de Automação de Treinamentos</h1>
            <p>
              {step === 'email' && 'Informe seu e-mail para continuar.'}
              {step === 'password' && 'Informe sua senha para continuar.'}
              {step === 'otp' && 'Informe o código enviado ao seu e-mail.'}
            </p>
          </div>

          {/* ── Etapa 1: e-mail ───────────────────────────────── */}
          {step === 'email' && (
            <form onSubmit={handleEmailSubmit} className={styles.form}>
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
                <span />
                <button type="submit" disabled={isLoading} className={styles.submitBtn}>
                  {isLoading && <Loader2 size={16} className={styles.spinner} />}
                  {isLoading ? 'Verificando…' : 'Continuar'}
                </button>
              </div>

              {error && <p className={styles.errorMsg}>{error}</p>}
            </form>
          )}

          {/* ── Etapa 2a: senha (ADMIN/CONSULTANT) ────────────── */}
          {step === 'password' && (
            <form onSubmit={handlePasswordSubmit} className={styles.form}>
              <button type="button" onClick={resetToEmailStep} className={styles.forgotBtn} style={{ display: 'flex', alignItems: 'center', gap: 6, alignSelf: 'flex-start' }}>
                <ArrowLeft size={14} /> {email}
              </button>

              <div className={styles.field}>
                <label htmlFor="password" className={styles.label}>
                  Senha
                </label>
                <div className={styles.passwordWrapper}>
                  <input
                    id="password"
                    type={showPassword ? 'text' : 'password'}
                    autoComplete="current-password"
                    autoFocus
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    placeholder="••••••••"
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

              <div className={styles.formRow}>
                <Link href="/forgot-password" className={styles.forgotBtn}>
                  Esqueci minha senha
                </Link>
                <button type="submit" disabled={isLoading} className={styles.submitBtn}>
                  {isLoading && <Loader2 size={16} className={styles.spinner} />}
                  {isLoading ? 'Entrando…' : 'Entrar'}
                </button>
              </div>

              {error && <p className={styles.errorMsg}>{error}</p>}
            </form>
          )}

          {/* ── Etapa 2b: código OTP (CLIENT) ─────────────────── */}
          {step === 'otp' && (
            <form onSubmit={handleOtpSubmit} className={styles.form}>
              <button type="button" onClick={resetToEmailStep} className={styles.forgotBtn} style={{ display: 'flex', alignItems: 'center', gap: 6, alignSelf: 'flex-start' }}>
                <ArrowLeft size={14} /> {email}
              </button>

              <div className={styles.field}>
                <label htmlFor="otp" className={styles.label}>
                  Código de acesso
                </label>
                <input
                  id="otp"
                  type="text"
                  inputMode="numeric"
                  autoComplete="one-time-code"
                  autoFocus
                  maxLength={6}
                  value={otpCode}
                  onChange={(e) => setOtpCode(e.target.value.replace(/\D/g, '').slice(0, 6))}
                  placeholder="000000"
                  className={styles.input}
                  style={{ letterSpacing: '4px', textAlign: 'center', fontSize: '1.1rem' }}
                  disabled={isLoading}
                />
              </div>

              {info && !error && <p style={{ fontSize: '0.875rem', color: 'var(--text-2)' }}>{info}</p>}

              <div className={styles.formRow}>
                <button type="button" onClick={handleResendOtp} disabled={isLoading} className={styles.forgotBtn}>
                  Reenviar código
                </button>
                <button type="submit" disabled={isLoading} className={styles.submitBtn}>
                  {isLoading && <Loader2 size={16} className={styles.spinner} />}
                  {isLoading ? 'Confirmando…' : 'Confirmar'}
                </button>
              </div>

              {error && <p className={styles.errorMsg}>{error}</p>}
            </form>
          )}

        </div>
      </div>
    </div>
  )
}
