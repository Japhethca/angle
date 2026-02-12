import React from "react";
import { Head } from "@inertiajs/react";
import { LoginForm } from "../../components/forms/login-form";
import { AuthLayout } from "../../components/layouts/auth-layout";
import { AuthProvider } from "../../contexts/auth-context";

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
