'use client'

import { ToastProvider } from '@/components/ui/toast/toast-provider'
import { ConfirmDialogProvider } from '@/components/ui/confirm-dialog/confirm-dialog-provider'
import { PageTitleProvider } from '@/components/header/page-title-context'
import { CurrentUserProvider } from '@/components/current-user-context'

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <CurrentUserProvider>
      <PageTitleProvider>
        <ToastProvider>
          <ConfirmDialogProvider>
            {children}
          </ConfirmDialogProvider>
        </ToastProvider>
      </PageTitleProvider>
    </CurrentUserProvider>
  )
}
