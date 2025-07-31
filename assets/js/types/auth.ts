export interface User {
  id: string;
  email: string;
  confirmed_at: string | null;
}

export interface AuthState {
  authenticated: boolean;
  user: User | null;
}

export interface PageProps {
  auth: AuthState;
  flash: {
    info?: string;
    error?: string;
    success?: string;
  };
  csrf_token: string;
  [key: string]: any;
}