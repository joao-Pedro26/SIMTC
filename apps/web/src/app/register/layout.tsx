import { PublicHeader } from '@/components/header/public-header'

export default function RegisterLayout({ children }: { children: React.ReactNode }) {
  return (
    <>
      <PublicHeader />
      {children}
    </>
  )
}
