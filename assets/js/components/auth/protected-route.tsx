import { ReactNode } from 'react';
import { router } from '@inertiajs/react';
import { useAuth } from '../../contexts/auth-context';

interface ProtectedRouteProps {
  children: ReactNode;
  fallback?: ReactNode;
}

export function ProtectedRoute({ children, fallback }: ProtectedRouteProps) {
  const { authenticated } = useAuth();

  if (!authenticated) {
    if (fallback) {
      return <>{fallback}</>;
    }
    
    // Redirect to login (this will be handled by backend middleware)
    router.visit('/auth/login');
    return null;
  }

  return <>{children}</>;
}