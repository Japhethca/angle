import { createContext, useContext, ReactNode } from "react";
import { usePage } from "@inertiajs/react";
import { AuthState, PageProps } from "../types/auth";

interface AuthContextType extends AuthState {
  isLoading: boolean;
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

  const value: AuthContextType = {
    ...authData,
    isLoading: false,
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
