import { api } from '@/lib/api'
import { DocumentsClient } from './documents-client'

interface Certificate {
  id: string
  pdfUrl: string | null
  generatedAt: string | null
  sentToParticipant: boolean
  sentToCompany: boolean
}

interface CertificateRow {
  participantId: string
  participantName: string
  certificate: Certificate | null
}

interface Props {
  params: Promise<{ id: string }>
}

export default async function DocumentosPage({ params }: Props) {
  const { id } = await params
  const rows = await api.get<CertificateRow[]>(`/training-sessions/${id}/certificates`)

  return (
    <div>
      <h1 style={{ marginBottom: '1.5rem', fontSize: '1.25rem', fontWeight: 700 }}>
        Documentos
      </h1>
      <DocumentsClient sessionId={id} rows={rows} />
    </div>
  )
}
