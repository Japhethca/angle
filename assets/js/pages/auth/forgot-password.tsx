import React from "react";
import { Head, usePage } from "@inertiajs/react";
import { ForgotPasswordForm, AuthProvider } from "@/features/auth";
import type { PageProps } from "@/features/auth";
import { AuthLayout } from "@/layouts/auth-layout";
import { Alert, AlertDescription } from "@/components/ui/alert";

interface ForgotPasswordPageProps extends PageProps {
  error?: string;
}

export default function ForgotPassword() {
  const { props } = usePage<ForgotPasswordPageProps>();
  const { error } = props;

  return (
    <>
      <Head title="Recover Password" />
      <AuthLayout heroImage="/images/auth-hero-recover.png">
        <div className="space-y-6">
          <div>
            <h1 className="text-2xl font-bold tracking-tight text-content">
              Recover Password
            </h1>
            <p className="mt-2 text-sm text-content-secondary">
              Don't worry, we'll send a reset link to your email
            </p>
          </div>
          {error && (
            <Alert variant="destructive">
              <AlertDescription>{error}</AlertDescription>
            </Alert>
          )}
          <ForgotPasswordForm />
        </div>
      </AuthLayout>
    </>
  );
}

ForgotPassword.layout = (page: React.ReactNode) => (
  <AuthProvider>{page}</AuthProvider>
);
