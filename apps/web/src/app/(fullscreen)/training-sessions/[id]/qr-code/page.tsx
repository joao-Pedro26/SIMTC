import { ArrowLeft } from 'lucide-react'
import Image from 'next/image'
import Link from 'next/link'
import { api } from '@/lib/api'
import styles from './page.module.css'

interface QRCodePageProps {
  params: Promise<{ id: string }>
}

interface SessionData {
  id: string
  qrCodeToken: string
  company: { name: string }
  course: { name: string }
}

export default async function QRCodeProjectionPage({ params }: QRCodePageProps) {
  const { id } = await params

  let session: SessionData | null = null
  try {
    session = await api.get<SessionData>(`/training-sessions/${id}`)
  } catch {
    // not found or auth error
  }

  if (!session) {
    return (
      <div className={styles.notFound}>
        <p>Treinamento não encontrado.</p>
        <Link href="/training-sessions" className={styles.backLink}>
          ← Voltar para treinamentos
        </Link>
      </div>
    )
  }

  // O backend expõe a imagem PNG em GET /api/training-sessions/:id/qr-code
  const apiUrl = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3001/api'
  const qrImageUrl = `${apiUrl}/training-sessions/${id}/qr-code`
  const publicRegisterUrl = `${process.env.NEXT_PUBLIC_APP_URL ?? 'http://localhost:3000'}/register/${session.qrCodeToken}`

  return (
    <div className={styles.page}>

      <div className={styles.topBar}>
        <Link href="/training-sessions" className={styles.backBtn}>
          <ArrowLeft size={16} /> Voltar
        </Link>
        <div className={styles.sessionInfo}>
          <span className={styles.companyName}>{session.company.name}</span>
          <span className={styles.separator}>·</span>
          <span className={styles.courseName}>{session.course.name}</span>
        </div>
      </div>

      <div className={styles.center}>
        <div className={styles.qrBox}>
          {/* QR Code gerado pelo backend */}
          <img
            src={qrImageUrl}
            alt="QR Code de inscrição"
            style={{ width: 280, height: 280 }}
          />
        </div>
        <p className={styles.url}>{publicRegisterUrl}</p>
        <p className={styles.instruction}>
          Aponte a câmera do celular para o QR Code acima para se cadastrar no treinamento.
        </p>
      </div>
    </div>
  )
}
