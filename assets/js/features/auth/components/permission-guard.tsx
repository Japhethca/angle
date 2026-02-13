import { ReactNode } from "react";
import { useAuth } from "../contexts/auth-context";

interface PermissionGuardProps {
  children: ReactNode;
  permission?: string;
  permissions?: string[];
  role?: string;
  roles?: string[];
  requireAll?: boolean;
  fallback?: ReactNode;
}

/**
 * Permission-based component guard that conditionally renders children based on user permissions or roles.
 * 
 * Examples:
 * <PermissionGuard permission="create_items">
 *   <CreateItemButton />
 * </PermissionGuard>
 * 
 * <PermissionGuard permissions={["place_bids", "view_bids"]} requireAll={false}>
 *   <BiddingSection />
 * </PermissionGuard>
 * 
 * <PermissionGuard role="admin" fallback={<div>Access denied</div>}>
 *   <AdminPanel />
 * </PermissionGuard>
 */
export function PermissionGuard({
  children,
  permission,
  permissions = [],
  role,
  roles = [],
  requireAll = true,
  fallback = null,
}: PermissionGuardProps) {
  const auth = useAuth();

  // If not authenticated, don't show anything
  if (!auth.authenticated) {
    return <>{fallback}</>;
  }

  let hasAccess = true;

  // Check single permission
  if (permission) {
    hasAccess = auth.hasPermission(permission);
  }

  // Check multiple permissions
  if (permissions.length > 0) {
    hasAccess = requireAll 
      ? auth.hasAllPermissions(permissions)
      : auth.hasAnyPermission(permissions);
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

  return hasAccess ? <>{children}</> : <>{fallback}</>;
}

// Convenience components for common use cases
export function AdminOnly({ children, fallback = null }: { children: ReactNode; fallback?: ReactNode }) {
  return (
    <PermissionGuard role="admin" fallback={fallback}>
      {children}
    </PermissionGuard>
  );
}

export function SellerOnly({ children, fallback = null }: { children: ReactNode; fallback?: ReactNode }) {
  return (
    <PermissionGuard role="seller" fallback={fallback}>
      {children}
    </PermissionGuard>
  );
}

export function BidderOnly({ children, fallback = null }: { children: ReactNode; fallback?: ReactNode }) {
  return (
    <PermissionGuard roles={["user", "bidder"]} requireAll={false} fallback={fallback}>
      {children}
    </PermissionGuard>
  );
}

// Permission-specific guards
export function CanCreateItems({ children, fallback = null }: { children: ReactNode; fallback?: ReactNode }) {
  return (
    <PermissionGuard permission="create_items" fallback={fallback}>
      {children}
    </PermissionGuard>
  );
}

export function CanPlaceBids({ children, fallback = null }: { children: ReactNode; fallback?: ReactNode }) {
  return (
    <PermissionGuard permission="place_bids" fallback={fallback}>
      {children}
    </PermissionGuard>
  );
}

export function CanManageUsers({ children, fallback = null }: { children: ReactNode; fallback?: ReactNode }) {
  return (
    <PermissionGuard permission="manage_users" fallback={fallback}>
      {children}
    </PermissionGuard>
  );
}