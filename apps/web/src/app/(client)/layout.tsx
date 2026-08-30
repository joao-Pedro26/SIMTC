import { ClientHeader } from '@/components/header/client-header'
import { Providers } from '@/components/providers'
import styles from './client-layout.module.css'

export default function ClientLayout({ children }: { children: React.ReactNode }) {
  return (
    <Providers>
      <div className={styles.shell}>
        <ClientHeader />
        <main className={styles.content}>
          {children}
        </main>
      </div>
    </Providers>
  )
}
