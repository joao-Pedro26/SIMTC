import type { TrainingStatus } from './types'
import styles from './training-session-status-badge.module.css'

interface TrainingSessionStatusBadgeProps {
  status: TrainingStatus
}

const labels: Record<TrainingStatus, string> = {
  PLANEJADO: 'Planejado',
  EM_ANDAMENTO: 'Em Andamento',
  CONCLUIDO: 'Concluído',
  CANCELADO: 'Cancelado',
}

export function TrainingSessionStatusBadge({ status }: TrainingSessionStatusBadgeProps) {
  return (
    <span className={`${styles.badge} ${styles[status]}`}>
      {labels[status]}
    </span>
  )
}
