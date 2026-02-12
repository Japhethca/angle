import React from "react";
import { Head } from "@inertiajs/react";
import { RegisterForm } from "../../components/forms/register-form";
import { AuthLayout } from "../../components/layouts/auth-layout";
import { AuthProvider } from "../../contexts/auth-context";

export default function Register() {
  return (
    <>
      <Head title="Sign Up" />
      <AuthLayout>
        <RegisterForm />
      </AuthLayout>
    </>
  );
}

Register.layout = (page: React.ReactNode) => <AuthProvider>{page}</AuthProvider>;
