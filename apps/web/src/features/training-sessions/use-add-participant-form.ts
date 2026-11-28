'use client'

import { useCallback, useEffect, useRef, useState } from 'react'
import { clientApi } from '@/lib/client-api'
import { CNH_CATEGORIES, cpfError, maskCpf, validateCpf } from '@/lib/validate-cpf'

/**
 * Formulário "adicionar participante", usado pela aba Participantes e pelo
 * Gerenciar Sessão. Segue a tela do app mobile: o CPF vem primeiro e, completo
 * e válido, é consultado no servidor, que diz se a pessoa já está na sessão e
 * devolve o cadastro de outro treinamento (nome, e-mail e CNH) para preencher.
 */

/** `POST /training-sessions/:id/participants/lookup` (só ADMIN). */
interface CpfLookup {
  registered: boolean
  enrolled: boolean
  name: string | null
  email: string | null
  cnhCategory: string | null
  /** `AAAA-MM-DD`, o mesmo formato do `<input type="date">`. */
  cnhExpiration: string | null
}

const REGISTRY_FIELDS = ['name', 'email', 'cnhCategory', 'cnhExpiration'] as const
type RegistryField = (typeof REGISTRY_FIELDS)[number]
type Values = Record<RegistryField | 'cpf', string>
/** O que a consulta pôs nos campos. */
type AutoFill = Partial<Record<RegistryField, string>>

const emptyValues: Values = { cpf: '', name: '', email: '', cnhCategory: '', cnhExpiration: '' }

type CpfStatus = 'idle' | 'checking' | 'available' | 'enrolled' | 'unverified'

/** Passou disso, a consulta conta como falha e os campos destravam. */
const LOOKUP_TIMEOUT_MS = 8000

const FIELD_LABELS: Record<RegistryField, string> = {
  name: 'nome',
  email: 'e-mail',
  cnhCategory: 'CNH',
  cnhExpiration: 'CNH',
}

function registryNotice(auto: AutoFill): string | null {
  const items = Array.from(
    new Set(REGISTRY_FIELDS.filter((f) => auto[f] !== undefined).map((f) => FIELD_LABELS[f])),
  )
  if (items.length === 0) return null
  const filled =
    items.length === 1
      ? `${items[0]} ${items[0] === 'CNH' ? 'preenchida' : 'preenchido'}`
      : `${items.slice(0, -1).join(', ')} e ${items[items.length - 1]} preenchidos`
  return `Já cadastrado em outro treinamento: ${filled}. Altere se precisar.`
}

/** Mesma faixa de anos do app: um ano com 2 ou 3 dígitos não é uma CNH de verdade. */
function isValidExpiration(value: string): boolean {
  return /^20\d{2}-\d{2}-\d{2}$/.test(value)
}

function fetchLookup(sessionId: string, cpf: string): Promise<CpfLookup> {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('timeout')), LOOKUP_TIMEOUT_MS)
    clientApi
      .post<CpfLookup>(`/training-sessions/${sessionId}/participants/lookup`, { cpf })
      .then(resolve, reject)
      .finally(() => clearTimeout(timer))
  })
}

interface Options {
  /**
   * A consulta achou o CPF já inscrito nesta sessão — pode ter entrado pelo QR
   * code com a lista aberta. Quem puder recarregar a lista sem perder nada da
   * tela passa isto.
   */
  onEnrolled?: () => void
}

export function useAddParticipantForm(sessionId: string, { onEnrolled }: Options = {}) {
  const [{ values, auto }, setForm] = useState<{ values: Values; auto: AutoFill }>({
    values: emptyValues,
    auto: {},
  })
  const [cpfStatus, setCpfStatus] = useState<CpfStatus>('idle')
  const [enrolledName, setEnrolledName] = useState<string | null>(null)
  // CPF: o erro "incompleto" só aparece depois de sair do campo; o de dígito
  // verificador aparece assim que os 11 dígitos são digitados. O do vencimento
  // também espera a saída, porque o ano passa por 0002, 0020… enquanto é digitado.
  const [cpfTouched, setCpfTouched] = useState(false)
  const [expirationTouched, setExpirationTouched] = useState(false)
  const [focusName, setFocusName] = useState(false)
  const nameRef = useRef<HTMLInputElement>(null)
  /** Conta as consultas: a resposta só vale se for a da última. */
  const generation = useRef(0)

  const reset = useCallback(() => {
    generation.current++
    setForm({ values: emptyValues, auto: {} })
    setCpfStatus('idle')
    setEnrolledName(null)
    setCpfTouched(false)
    setExpirationTouched(false)
    setFocusName(false)
  }, [])

  useEffect(() => reset, [sessionId, reset])

  // Sem cadastro: o foco vai para o nome, que só destrava depois da resposta.
  useEffect(() => {
    if (!focusName) return
    nameRef.current?.focus()
    setFocusName(false)
  }, [focusName])

  async function lookup(cpf: string, current: number) {
    let result: CpfLookup | null = null
    try {
      result = await fetchLookup(sessionId, cpf)
    } catch {
      // Sem resposta: o admin preenche à mão e adiciona assim mesmo.
    }
    if (current !== generation.current) return

    if (typeof result?.enrolled !== 'boolean') {
      setCpfStatus('unverified')
    } else if (result.enrolled) {
      setCpfStatus('enrolled')
      setEnrolledName(result.name)
      onEnrolled?.()
    } else {
      setCpfStatus('available')
      if (!result.registered) {
        setFocusName(true)
        return
      }
      // O cadastro toma o lugar do que estiver nos campos; o que ele não tem
      // fica como está.
      const found: AutoFill = {}
      if (result.name) found.name = result.name
      if (result.email) found.email = result.email
      if (result.cnhCategory && (CNH_CATEGORIES as readonly string[]).includes(result.cnhCategory)) {
        found.cnhCategory = result.cnhCategory
      }
      if (result.cnhExpiration) found.cnhExpiration = result.cnhExpiration
      setForm((prev) => ({ values: { ...prev.values, ...found }, auto: found }))
    }
  }

  function setCpf(raw: string) {
    const masked = maskCpf(raw)
    if (masked === values.cpf) return
    const current = ++generation.current

    // O CPF mudou: o que veio do cadastro anterior sai, a não ser que o admin
    // tenha mexido no campo. Sem isso, a pessoa nova seria salva com o nome da
    // anterior.
    setForm((prev) => {
      const next = { ...prev.values, cpf: masked }
      for (const field of REGISTRY_FIELDS) {
        if (prev.auto[field] !== undefined && next[field] === prev.auto[field]) next[field] = ''
      }
      return { values: next, auto: {} }
    })
    setEnrolledName(null)

    const digits = masked.replace(/\D/g, '')
    if (validateCpf(digits)) {
      setCpfStatus('checking')
      void lookup(digits, current)
    } else {
      setCpfStatus('idle')
    }
  }

  function setField(field: RegistryField, value: string) {
    setForm((prev) => ({ ...prev, values: { ...prev.values, [field]: value } }))
  }

  const cpfDigits = values.cpf.replace(/\D/g, '')

  const cpfErrorMessage =
    cpfStatus === 'enrolled'
      ? enrolledName
        ? `${enrolledName} já está nesta sessão.`
        : 'Este CPF já está nesta sessão.'
      : cpfTouched || cpfDigits.length === 11
        ? cpfError(values.cpf)
        : null

  const cpfHelper =
    cpfStatus === 'checking'
      ? 'Consultando o CPF…'
      : cpfStatus === 'available'
        ? 'CPF válido e sem cadastro nesta sessão.'
        : cpfStatus === 'unverified'
          ? 'Não foi possível consultar o CPF. Preencha os dados e adicione assim mesmo.'
          : null

  const canSubmit =
    (cpfStatus === 'available' || cpfStatus === 'unverified') &&
    values.name.trim() !== '' &&
    values.cnhCategory !== '' &&
    isValidExpiration(values.cnhExpiration)

  /** Lança o erro da API; o formulário só é zerado quando o participante entra. */
  async function submit() {
    await clientApi.post(`/training-sessions/${sessionId}/participants`, {
      name: values.name.trim(),
      cpf: cpfDigits,
      email: values.email.trim() || undefined,
      cnhCategory: values.cnhCategory,
      cnhExpiration: values.cnhExpiration,
    })
    reset()
  }

  return {
    values,
    setCpf,
    setField,
    touchCpf: () => setCpfTouched(true),
    touchExpiration: () => setExpirationTouched(true),
    nameRef,
    /** A consulta está no ar: o cadastro não troca o texto sob o cursor. */
    isCheckingCpf: cpfStatus === 'checking',
    cpfError: cpfErrorMessage,
    cpfHelper: cpfErrorMessage ? null : cpfHelper,
    expirationError:
      expirationTouched && values.cnhExpiration && !isValidExpiration(values.cnhExpiration)
        ? 'Data inválida.'
        : null,
    registryNotice: registryNotice(auto),
    canSubmit,
    submit,
    reset,
  }
}
