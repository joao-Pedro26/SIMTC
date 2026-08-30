import Image from 'next/image'
import { cookies } from 'next/headers'
import { MapPin, CreditCard } from 'lucide-react'
import { api } from '@/lib/api'
import { PageTitle } from '@/components/header/page-title'
import { HistoryTable, type TrainingHistoryItem } from './history-table'
import styles from './page.module.css'

interface Company {
  id: string
  name: string
  cnpj: string
  address: string
  city: string
  state: string
  logoUrl?: string | null
}

function applyCnpjMask(value: string): string {
  const d = value.replace(/\D/g, '').slice(0, 14)
  if (d.length <= 2) return d
  if (d.length <= 5) return `${d.slice(0, 2)}.${d.slice(2)}`
  if (d.length <= 8) return `${d.slice(0, 2)}.${d.slice(2, 5)}.${d.slice(5)}`
  if (d.length <= 12) return `${d.slice(0, 2)}.${d.slice(2, 5)}.${d.slice(5, 8)}/${d.slice(8)}`
  return `${d.slice(0, 2)}.${d.slice(2, 5)}.${d.slice(5, 8)}/${d.slice(8, 12)}-${d.slice(12)}`
}

export default async function MinhaEmpresaPage() {
  // Reads companyId from the JWT payload (base64-decoded). The middleware already
  // validates the signature — we only need the claim value here.
  const cookieStore = await cookies()
  const token = cookieStore.get('simtc-token')?.value
  let companyId: string | null = null
  if (token) {
    try {
      const [, payloadB64] = token.split('.')
      const payload = JSON.parse(Buffer.from(payloadB64, 'base64url').toString('utf-8')) as { companyId?: string }
      companyId = payload.companyId ?? null
    } catch {
      /* leave null */
    }
  }

  if (!companyId) {
    return (
      <div className={styles.page}>
        <PageTitle title="Minha Empresa" />
        <p className={styles.error}>Não foi possível identificar a empresa do usuário.</p>
      </div>
    )
  }

  const [company, history] = await Promise.all([
    api.get<Company>(`/companies/${companyId}`),
    api.get<TrainingHistoryItem[]>(`/reports/companies/${companyId}/history`),
  ])

  return (
    <div className={styles.page}>
      <PageTitle title="Minha Empresa" />

      {/* Header card */}
      <div className={styles.headerCard}>
        <div className={styles.logoWrapper}>
          <Image
            src={company.logoUrl ?? '/logo-simtc.png'}
            alt={`Logo ${company.name}`}
            fill
            unoptimized
            style={{ objectFit: 'contain', padding: '0.75rem' }}
          />
        </div>
        <div className={styles.companyInfo}>
          <h1 className={styles.companyName}>{company.name}</h1>
          <div className={styles.metaRow}>
            <CreditCard size={14} className={styles.metaIcon} />
            <span>{applyCnpjMask(company.cnpj)}</span>
          </div>
          {(company.address || company.city) && (
            <div className={styles.metaRow}>
              <MapPin size={14} className={styles.metaIcon} />
              <span>
                {[company.address, company.city, company.state].filter(Boolean).join(', ')}
              </span>
            </div>
          )}
        </div>
      </div>

      {/* Training history */}
      <div className={styles.section}>
        <h2 className={styles.sectionTitle}>Histórico de Treinamentos</h2>

        <HistoryTable history={history} />
      </div>
    </div>
  )
}
