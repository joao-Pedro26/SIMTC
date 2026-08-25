import { notFound } from 'next/navigation'
import { api } from '@/lib/api'
import { PageTitle } from '@/components/header/page-title'
import { TrainingDetailClient } from './training-detail-client'
import type { AssessmentReportRow, CertificateRow, SessionDetail } from './types'

interface PageParams {
  params: Promise<{ id: string }>
}

export default async function TrainingDetailPage({ params }: PageParams) {
  const { id } = await params

  let session: SessionDetail
  let reportRows: AssessmentReportRow[]
  let certRows: CertificateRow[]

  try {
    ;[session, reportRows, certRows] = await Promise.all([
      api.get<SessionDetail>(`/reports/training-sessions/${id}`),
      api.get<AssessmentReportRow[]>(`/training-sessions/${id}/assessment-reports`),
      api.get<CertificateRow[]>(`/training-sessions/${id}/certificates`),
    ])
  } catch {
    notFound()
  }

  return (
    <>
      <PageTitle title={session!.course.name} />
      <TrainingDetailClient session={session!} reportRows={reportRows!} certRows={certRows!} />
    </>
  )
}
