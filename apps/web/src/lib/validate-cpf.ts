/**
 * Valida os dígitos verificadores de um CPF. Aceita com ou sem máscara.
 * Copiada de public-register-flow.tsx (que não exporta a função).
 */
export function validateCpf(cpf: string): boolean {
  const digits = cpf.replace(/\D/g, '')
  if (digits.length !== 11 || /^(\d)\1{10}$/.test(digits)) return false
  let sum = 0
  for (let i = 0; i < 9; i++) sum += Number(digits[i]) * (10 - i)
  let check = (sum * 10) % 11
  if (check === 10 || check === 11) check = 0
  if (check !== Number(digits[9])) return false
  sum = 0
  for (let i = 0; i < 10; i++) sum += Number(digits[i]) * (11 - i)
  check = (sum * 10) % 11
  if (check === 10 || check === 11) check = 0
  return check === Number(digits[10])
}

/** Regex do atributo HTML `pattern` para CPF mascarado (000.000.000-00). */
export const CPF_PATTERN = '\\d{3}\\.\\d{3}\\.\\d{3}-\\d{2}'

/**
 * Aplica a máscara 000.000.000-00 progressivamente enquanto o usuário digita.
 * Descarta tudo que não for dígito e limita a 11 dígitos.
 */
export function maskCpf(value: string): string {
  const d = value.replace(/\D/g, '').slice(0, 11)
  if (d.length <= 3) return d
  if (d.length <= 6) return `${d.slice(0, 3)}.${d.slice(3)}`
  if (d.length <= 9) return `${d.slice(0, 3)}.${d.slice(3, 6)}.${d.slice(6)}`
  return `${d.slice(0, 3)}.${d.slice(3, 6)}.${d.slice(6, 9)}-${d.slice(9)}`
}

/**
 * Mensagem de erro para exibir sob o campo de CPF, ou `null` se estiver ok.
 * Campo vazio não é erro aqui (a obrigatoriedade é tratada pelo botão).
 */
export function cpfError(value: string): string | null {
  const digits = value.replace(/\D/g, '')
  if (digits.length === 0) return null
  if (digits.length < 11) return 'CPF incompleto.'
  if (!validateCpf(digits)) return 'CPF inválido — verifique os dígitos.'
  return null
}

/** Categorias de CNH aceitas (mesma lista do formulário público de inscrição). */
export const CNH_CATEGORIES = ['A', 'B', 'C', 'D', 'E', 'AB', 'AC', 'AD', 'AE'] as const
