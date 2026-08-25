'use client'

import { useState } from 'react'
import { Loader2 } from 'lucide-react'
import { Button } from '@/components/ui/button/button'
import { clientApi } from '@/lib/client-api'
import { useToast } from '@/components/ui/toast/toast-provider'
import { PageTitle } from '@/components/header/page-title'
import styles from './profile.module.css'

export default function MeuPerfilPage() {
  const toast = useToast()

  const [form, setForm] = useState({
    currentPassword: '',
    newPassword: '',
    confirmPassword: '',
  })
  const [loading, setLoading] = useState(false)

  function handleChange(field: keyof typeof form, value: string) {
    setForm((prev) => ({ ...prev, [field]: value }))
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()

    if (form.newPassword !== form.confirmPassword) {
      toast.error('A nova senha e a confirmação não coincidem.')
      return
    }

    if (form.newPassword.length < 6) {
      toast.error('A nova senha deve ter pelo menos 6 caracteres.')
      return
    }

    setLoading(true)
    try {
      await clientApi.patch('/users/me/password', {
        currentPassword: form.currentPassword,
        newPassword: form.newPassword,
      })
      toast.success('Senha alterada com sucesso.')
      setForm({ currentPassword: '', newPassword: '', confirmPassword: '' })
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Erro ao alterar a senha.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className={styles.page}>
      <PageTitle title="Meu Perfil" />

      <section className={styles.card}>
        <h2 className={styles.sectionTitle}>Alterar senha</h2>

        <form onSubmit={handleSubmit} className={styles.form}>
          <div className={styles.field}>
            <label className={styles.label} htmlFor="currentPassword">Senha atual</label>
            <input
              id="currentPassword"
              type="password"
              className={styles.input}
              value={form.currentPassword}
              onChange={(e) => handleChange('currentPassword', e.target.value)}
              required
              autoComplete="current-password"
            />
          </div>

          <div className={styles.field}>
            <label className={styles.label} htmlFor="newPassword">Nova senha</label>
            <input
              id="newPassword"
              type="password"
              className={styles.input}
              value={form.newPassword}
              onChange={(e) => handleChange('newPassword', e.target.value)}
              required
              autoComplete="new-password"
            />
          </div>

          <div className={styles.field}>
            <label className={styles.label} htmlFor="confirmPassword">Confirmar nova senha</label>
            <input
              id="confirmPassword"
              type="password"
              className={styles.input}
              value={form.confirmPassword}
              onChange={(e) => handleChange('confirmPassword', e.target.value)}
              required
              autoComplete="new-password"
            />
          </div>

          <div className={styles.actions}>
            <Button type="submit" variant="primary" size="sm" disabled={loading}>
              {loading && <Loader2 size={14} className={styles.spinner} />}
              {loading ? 'Salvando...' : 'Salvar nova senha'}
            </Button>
          </div>
        </form>
      </section>
    </div>
  )
}
