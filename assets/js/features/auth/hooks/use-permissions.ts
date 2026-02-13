import { useAuth } from "@/features/auth/contexts/auth-context";

/**
 * Custom hooks for permission checking
 */

export function usePermissions() {
  const auth = useAuth();

  return {
    hasRole: auth.hasRole,
    hasPermission: auth.hasPermission,
    hasAnyRole: auth.hasAnyRole,
    hasAnyPermission: auth.hasAnyPermission,
    hasAllPermissions: auth.hasAllPermissions,
    user: auth.user,
    isAuthenticated: auth.authenticated,
  };
}

export function useRole(roleName: string) {
  const { hasRole } = usePermissions();
  return hasRole(roleName);
}

export function usePermission(permissionName: string) {
  const { hasPermission } = usePermissions();
  return hasPermission(permissionName);
}

// Specific permission hooks for common checks
export function useCanCreateItems() {
  return usePermission("create_items");
}

export function useCanUpdateItems() {
  return usePermission("update_own_items");
}

export function useCanDeleteItems() {
  return usePermission("delete_own_items");
}

export function useCanPublishItems() {
  return usePermission("publish_items");
}

export function useCanPlaceBids() {
  return usePermission("place_bids");
}

export function useCanViewBids() {
  return usePermission("view_bids");
}

export function useCanManageBids() {
  return usePermission("manage_bids");
}

export function useCanManageUsers() {
  return usePermission("manage_users");
}

export function useCanManageRoles() {
  return usePermission("manage_roles");
}

export function useCanManagePermissions() {
  return usePermission("manage_permissions");
}

export function useCanReadCatalog() {
  return usePermission("read_catalog");
}

export function useCanManageCatalog() {
  return usePermission("manage_catalog");
}

// Role-based hooks
export function useIsAdmin() {
  return useRole("admin");
}

export function useIsSeller() {
  return useRole("seller");
}

export function useIsBidder() {
  return useRole("user") || useRole("bidder");
}

export function useIsViewer() {
  return useRole("viewer");
}