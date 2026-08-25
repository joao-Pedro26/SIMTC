'use client'

import { ExternalLink, Copy } from 'lucide-react'
import { Button } from '@/components/ui/button/button'
import type { TrainingSession } from './types'
import styles from './qr-code-tab.module.css'

const API_URL = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3001/api'
const APP_URL = process.env.NEXT_PUBLIC_APP_URL ?? 'http://localhost:3000'

interface QrCodeTabProps {
  session: TrainingSession
}

export function QrCodeTab({ session }: QrCodeTabProps) {
  const publicUrl = `${APP_URL}/register/${session.qrCodeToken}`
  const qrImageUrl = `${API_URL}/training-sessions/${session.id}/qr-code`

  function copyLink() {
    navigator.clipboard.writeText(publicUrl)
  }

  return (
    <div className={styles.wrapper}>
      <div className={styles.qrPlaceholder}>
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={qrImageUrl}
          alt={`QR Code — ${session.company.name}`}
          width={200}
          height={200}
          style={{ display: 'block' }}
        />
        <p className={styles.qrLabel}>QR Code — {session.company.name}</p>
      </div>
      <div className={styles.linkBox}>
        <p className={styles.linkLabel}>Link do formulário público:</p>
        <p className={styles.linkUrl}>{publicUrl}</p>
      </div>
      <div className={styles.actions}>
        <Button variant="secondary" size="sm" onClick={copyLink}>
          <Copy size={14} /> Copiar link
        </Button>
        <Button
          variant="primary"
          size="sm"
          onClick={() => window.open(`/training-sessions/${session.id}/qr-code`, '_blank')}
        >
          <ExternalLink size={14} /> Abrir em tela cheia
        </Button>
      </div>
      <p className={styles.hint}>
        Projete o QR Code na sala para que os participantes façam o auto-cadastro pelo celular, sem precisar digitar nenhum código de turma.
      </p>
    </div>
  )
}
