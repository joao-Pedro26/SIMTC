import styles from './status-badge.module.css'

type Status = 'ativo' | 'inativo'

interface StatusBadgeProps {
  status: Status
}

const labels: Record<Status, string> = {
  ativo: 'Ativo',
  inativo: 'Inativo',
}

export function StatusBadge({ status }: StatusBadgeProps) {
  return (
    <span className={`${styles.badge} ${styles[status]}`}>
      {labels[status]}
    </span>
  )
}
