import { PublicRegisterFlow } from './public-register-flow'
import styles from './public-register.module.css'

const API_URL = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3001/api'

interface RegisterPageProps {
  params: Promise<{ qrToken: string }>
}

interface SessionInfo {
  companyName: string
  companyLogoUrl: string | null
  courseName: string
  status: string
}

export default async function RegisterPage({ params }: RegisterPageProps) {
  const { qrToken } = await params

  let session: SessionInfo | null = null
  let notFound = false

  try {
    const res = await fetch(
      `${API_URL}/public/training-sessions/by-token/${qrToken}`,
      { cache: 'no-store' },
    )
    if (res.status === 404) {
      notFound = true
    } else if (res.ok) {
      session = await res.json()
    }
  } catch {
    notFound = true
  }

  const isEncerrado =
    session?.status === 'CANCELADO' || session?.status === 'CONCLUIDO'

  if (notFound) {
    return (
      <div className={styles.pageContent}>
        <div className={styles.inner}>
          <div className={styles.statePage}>
            <div className={`${styles.stateOrb} ${styles.stateOrbRed}`}>
              <svg width="34" height="34" viewBox="0 0 24 24" fill="none" stroke="#DC2626" strokeWidth="2" strokeLinecap="round">
                <circle cx="12" cy="12" r="10" />
                <line x1="15" y1="9" x2="9" y2="15" />
                <line x1="9" y1="9" x2="15" y2="15" />
              </svg>
            </div>
            <h2 className={styles.stateTitle}>QR Code inválido</h2>
            <p className={styles.stateDesc}>
              Este link não corresponde a nenhum treinamento. Verifique o QR Code e tente novamente.
            </p>
          </div>
        </div>
      </div>
    )
  }

  if (isEncerrado) {
    return (
      <div className={styles.pageContent}>
        <div className={styles.inner}>
          <div className={styles.statePage}>
            <div className={`${styles.stateOrb} ${styles.stateOrbAmber}`}>
              <svg width="34" height="34" viewBox="0 0 24 24" fill="none" stroke="#E09510" strokeWidth="2" strokeLinecap="round">
                <rect x="3" y="11" width="18" height="11" rx="2" />
                <path d="M7 11V7a5 5 0 0 1 10 0v4" />
              </svg>
            </div>
            <h2 className={styles.stateTitle}>Inscrições encerradas</h2>
            <p className={styles.stateDesc}>
              Este treinamento não está mais aceitando novas inscrições.
            </p>
          </div>
        </div>
      </div>
    )
  }

  return (
    <PublicRegisterFlow
      companyName={session!.companyName}
      companyLogoUrl={session!.companyLogoUrl}
      courseName={session!.courseName}
      qrToken={qrToken}
    />
  )
}
