import { ReactNode } from 'react';
import { router } from '@inertiajs/react';
import { useAuth } from '../../contexts/auth-context';

interface GuestRouteProps {
  children: ReactNode;
}

export function GuestRoute({ children }: GuestRouteProps) {
  const { authenticated } = useAuth();

  if (authenticated) {
    router.visit('/');
    return null;
  }

  return <>{children}</>;
}