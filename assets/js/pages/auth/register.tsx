import React from "react";
import { Head } from "@inertiajs/react";
import { RegisterForm, AuthProvider } from "@/features/auth";
import { AuthLayout } from "@/layouts/auth-layout";

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
