export interface Permission {
  name: string;
  resource: string;
  action: string;
  scope: string;
  description: string;
}

export interface Role {
  name: string;
  description: string;
  scope: string;
  permissions: Permission[];
}

export interface User {
  id: string;
  email: string;
  full_name: string | null;
  phone_number: string | null;
  confirmed_at: string | null;
  roles: string[];
  permissions: string[];
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