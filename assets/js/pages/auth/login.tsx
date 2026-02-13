import React from "react";
import { Head } from "@inertiajs/react";
import { LoginForm, AuthProvider } from "@/features/auth";
import { AuthLayout } from "@/layouts/auth-layout";

export default function Login() {
  return (
    <>
      <Head title="Sign In" />
      <AuthLayout>
        <LoginForm />
      </AuthLayout>
    </>
  );
}

Login.layout = (page: React.ReactNode) => <AuthProvider>{page}</AuthProvider>;
