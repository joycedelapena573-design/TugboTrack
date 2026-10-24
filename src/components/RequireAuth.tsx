/** Redirects away from protected screens until the MPIN has been entered. */
import { Redirect } from 'expo-router';
import type { ReactNode } from 'react';

import { useStore } from '@/lib/store';

export function RequireAuth({ children }: { children: ReactNode }) {
  const { ready, hasMpin, unlocked } = useStore();

  if (!ready) return null;
  if (!hasMpin) return <Redirect href="/mpin/setup" />;
  if (!unlocked) return <Redirect href="/mpin/unlock" />;
  return <>{children}</>;
}