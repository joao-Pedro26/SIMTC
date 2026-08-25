'use client';

import { UserRole } from '@simtc/shared-types';

export interface SessionUser {
  id: string;
  email: string;
  role: UserRole;
  consultantId?: string;
  companyId?: string;
}

/** Decodifica o JWT armazenado no cookie (client-side) */
export function getSessionUser(): SessionUser | null {
  if (typeof document === 'undefined') return null;
  const token = document.cookie
    .split('; ')
    .find((c) => c.startsWith('simtc-token='))
    ?.split('=')[1];
  if (!token) return null;

  try {
    const payload = JSON.parse(atob(token.split('.')[1]));
    return {
      id: payload.sub,
      email: payload.email,
      role: payload.role,
      consultantId: payload.consultantId,
      companyId: payload.companyId,
    };
  } catch {
    return null;
  }
}
