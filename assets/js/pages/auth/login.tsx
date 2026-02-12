import React from "react";
import { Head, usePage } from "@inertiajs/react";
import { LoginForm } from "../../components/forms/login-form";
import { AuthLayout } from "../../components/layouts/auth-layout";
import { AuthProvider } from "../../contexts/auth-context";
import { PageProps } from "../../types/auth";

interface LoginPageProps extends PageProps {
  error?: string;
}

export default function Login() {
  const { props } = usePage<LoginPageProps>();
  const { error } = props;

  return (
    <>
      <Head title="Sign In" />
      <AuthLayout>
        <LoginForm error={error} />
      </AuthLayout>
    </>
  );
}

Login.layout = (page: React.ReactNode) => <AuthProvider>{page}</AuthProvider>;
