import { ReactNode } from 'react';
import { router } from '@inertiajs/react';
import { useAuth } from '../contexts/auth-context';

interface ProtectedRouteProps {
  children: ReactNode;
  fallback?: ReactNode;
  permission?: string;
  permissions?: string[];
  role?: string;
  roles?: string[];
  requireAll?: boolean;
}

export function ProtectedRoute({ 
  children, 
  fallback,
  permission,
  permissions = [],
  role,
  roles = [],
  requireAll = true
}: ProtectedRouteProps) {
  const auth = useAuth();

  if (!auth.authenticated) {
    if (fallback) {
      return <>{fallback}</>;
    }
    
    // Redirect to login (this will be handled by backend middleware)
    router.visit('/auth/login');
    return null;
  }

  // Check permissions and roles if specified
  let hasAccess = true;

  // Check single permission
  if (permission) {
    hasAccess = auth.hasPermission(permission);
  }

  // Check multiple permissions
  if (permissions.length > 0) {
    hasAccess = hasAccess && (requireAll 
      ? auth.hasAllPermissions(permissions)
      : auth.hasAnyPermission(permissions));
  }

  // Check single role
  if (role) {
    hasAccess = hasAccess && auth.hasRole(role);
  }

  // Check multiple roles
  if (roles.length > 0) {
    const roleAccess = requireAll
      ? roles.every(r => auth.hasRole(r))
      : auth.hasAnyRole(roles);
    hasAccess = hasAccess && roleAccess;
  }

  if (!hasAccess) {
    if (fallback) {
      return <>{fallback}</>;
    }
    
    // Redirect to dashboard or home with access denied message
    router.visit('/dashboard', {
      data: { error: 'You do not have permission to access this page' }
    });
    return null;
  }

  return <>{children}</>;
}