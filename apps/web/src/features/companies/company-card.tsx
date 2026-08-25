import Image from 'next/image'
import { MapPin, CreditCard, CalendarCheck } from 'lucide-react'
import styles from './company-card.module.css'

interface CompanyCardProps {
  name: string
  address: string
  cnpj: string
  lastTraining: string
  logoUrl?: string
  onClick?: () => void
}

function applyCnpjMask(value: string): string {
  const d = value.replace(/\D/g, '').slice(0, 14)
  if (d.length <= 2) return d
  if (d.length <= 5) return `${d.slice(0, 2)}.${d.slice(2)}`
  if (d.length <= 8) return `${d.slice(0, 2)}.${d.slice(2, 5)}.${d.slice(5)}`
  if (d.length <= 12) return `${d.slice(0, 2)}.${d.slice(2, 5)}.${d.slice(5, 8)}/${d.slice(8)}`
  return `${d.slice(0, 2)}.${d.slice(2, 5)}.${d.slice(5, 8)}/${d.slice(8, 12)}-${d.slice(12)}`
}

export function CompanyCard({ name, address, cnpj, lastTraining, logoUrl, onClick }: CompanyCardProps) {
  return (
    <div className={styles.card} onClick={onClick}>
      {/* Área do logo */}
      <div className={styles.logoWrapper}>
        <Image
          src={logoUrl ?? '/logo-simtc.png'}
          alt={`Logo ${name}`}
          fill
          unoptimized
          style={{ objectFit: 'contain', padding: '1rem' }}
        />
      </div>

      {/* Informações */}
      <div className={styles.info}>
        <h2 className={styles.name}>{name}</h2>

        <div className={styles.meta}>
          <div className={styles.row}>
            <MapPin size={13} className={styles.icon} />
            <span className={styles.value}>{address || '—'}</span>
          </div>
          <div className={styles.row}>
            <CreditCard size={13} className={styles.icon} />
            <span className={styles.value}>{applyCnpjMask(cnpj)}</span>
          </div>
          <div className={styles.row}>
            <CalendarCheck size={13} className={styles.icon} />
            <span className={styles.value}>
              {lastTraining || 'Sem treinamentos registrados'}
            </span>
          </div>
        </div>
      </div>
    </div>
  )
}
