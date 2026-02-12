import React from "react";
import { Head, usePage } from "@inertiajs/react";
import { RegisterForm } from "../../components/forms/register-form";
import { AuthLayout } from "../../components/layouts/auth-layout";
import { AuthProvider } from "../../contexts/auth-context";
import { PageProps } from "../../types/auth";

interface RegisterPageProps extends PageProps {
  error?: string;
}

export default function Register() {
  const { props } = usePage<RegisterPageProps>();
  const { error } = props;

  return (
    <>
      <Head title="Sign Up" />
      <AuthLayout>
        <RegisterForm error={error} />
      </AuthLayout>
    </>
  );
}

Register.layout = (page: React.ReactNode) => <AuthProvider>{page}</AuthProvider>;
