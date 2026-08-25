import { Sidebar } from '@/components/sidebar/sidebar'
import { Header } from '@/components/header/header'
import { Providers } from '@/components/providers'
import styles from '../(admin)/layout.module.css'

export default function ClientLayout({ children }: { children: React.ReactNode }) {
  return (
    <Providers>
      <div className={styles.shell}>
        <Sidebar />
        <div className={styles.rightCol}>
          <Header />
          <main className={styles.content}>
            {children}
          </main>
        </div>
      </div>
    </Providers>
  )
}
