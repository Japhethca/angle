// Auth feature barrel export
export { AuthProvider, useAuth } from "./contexts/auth-context";
export { GuestRoute } from "./components/guest-route";
export { LogoutButton } from "./components/logout-button";
export {
  PermissionGuard,
  AdminOnly,
  SellerOnly,
  BidderOnly,
  CanCreateItems,
  CanPlaceBids,
  CanManageUsers,
} from "./components/permission-guard";
export { ProtectedRoute } from "./components/protected-route";
export { LoginForm } from "./components/login-form";
export { RegisterForm } from "./components/register-form";
export { ForgotPasswordForm } from "./components/forgot-password-form";
export { ResetPasswordForm } from "./components/reset-password-form";
export { AuthLink } from "./components/auth-link";
export { useAuthGuard } from "./hooks/use-auth-guard";
export {
  usePermissions,
  useRole,
  usePermission,
  useCanCreateItems,
  useCanUpdateItems,
  useCanDeleteItems,
  useCanPublishItems,
  useCanPlaceBids,
  useCanViewBids,
  useCanManageBids,
  useCanManageUsers,
  useCanManageRoles,
  useCanManagePermissions,
  useCanReadCatalog,
  useCanManageCatalog,
  useIsAdmin,
  useIsSeller,
  useIsBidder,
  useIsViewer,
} from "./hooks/use-permissions";
export type {
  Permission,
  Role,
  User,
  AuthState,
  PageProps,
} from "./types";
