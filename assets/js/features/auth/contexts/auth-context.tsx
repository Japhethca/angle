import { createContext, useContext, ReactNode } from "react";
import { usePage } from "@inertiajs/react";
import { AuthState, PageProps } from "../types";

interface AuthContextType extends AuthState {
  isLoading: boolean;
  hasRole: (roleName: string) => boolean;
  hasPermission: (permissionName: string) => boolean;
  hasAnyRole: (roleNames: string[]) => boolean;
  hasAnyPermission: (permissionNames: string[]) => boolean;
  hasAllPermissions: (permissionNames: string[]) => boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const pageProps = usePage<PageProps>().props;

  // Fallback: if auth prop is not available, try to construct it from available data
  let authData = pageProps.auth;
  if (!authData && (pageProps as any).user) {
    authData = {
      authenticated: true,
      user: (pageProps as any).user,
    };
  } else if (!authData) {
    authData = {
      authenticated: false,
      user: null,
    };
  }

  // Permission checking methods
  const hasRole = (roleName: string): boolean => {
    if (!authData.authenticated || !authData.user?.roles) return false;
    return authData.user.roles.includes(roleName);
  };

  const hasPermission = (permissionName: string): boolean => {
    if (!authData.authenticated || !authData.user?.permissions) return false;
    return authData.user.permissions.includes(permissionName);
  };

  const hasAnyRole = (roleNames: string[]): boolean => {
    if (!authData.authenticated || !authData.user?.roles) return false;
    return roleNames.some(role => authData.user!.roles.includes(role));
  };

  const hasAnyPermission = (permissionNames: string[]): boolean => {
    if (!authData.authenticated || !authData.user?.permissions) return false;
    return permissionNames.some(permission => authData.user!.permissions.includes(permission));
  };

  const hasAllPermissions = (permissionNames: string[]): boolean => {
    if (!authData.authenticated || !authData.user?.permissions) return false;
    return permissionNames.every(permission => authData.user!.permissions.includes(permission));
  };

  const value: AuthContextType = {
    ...authData,
    isLoading: false,
    hasRole,
    hasPermission,
    hasAnyRole,
    hasAnyPermission,
    hasAllPermissions,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error("useAuth must be used within an AuthProvider");
  }
  return context;
}
