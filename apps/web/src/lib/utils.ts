import { clsx, type ClassValue } from 'clsx'

/**
 * Combina nomes de classes condicionalmente.
 * Útil para combinar classes de CSS Modules:
 *   cn(styles.btn, isActive && styles.active)
 */
export function cn(...inputs: ClassValue[]) {
  return clsx(inputs)
}

/**
 * Formata um CPF numérico (11 dígitos) para o padrão 000.000.000-00.
 * Se o valor já vier com máscara ou tiver comprimento diferente, retorna como está.
 */
export function formatCpf(cpf: string): string {
  const d = cpf.replace(/\D/g, '')
  if (d.length !== 11) return cpf
  return `${d.slice(0, 3)}.${d.slice(3, 6)}.${d.slice(6, 9)}-${d.slice(9)}`
}
