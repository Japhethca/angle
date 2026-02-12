import React from "react";
import { Head, usePage } from "@inertiajs/react";
import { ResetPasswordForm } from "../../components/forms/reset-password-form";
import { AuthLayout } from "../../components/layouts/auth-layout";
import { AuthProvider } from "../../contexts/auth-context";
import { Alert, AlertDescription } from "../../components/ui/alert";
import { PageProps } from "../../types/auth";

interface ResetPasswordPageProps extends PageProps {
  token: string;
  error?: string;
}

export default function ResetPassword() {
  const { props } = usePage<ResetPasswordPageProps>();
  const { token, error } = props;

  return (
    <>
      <Head title="Change Password" />
      <AuthLayout heroImage="/images/auth-hero-recover.png">
        <div className="space-y-6">
          <div>
            <h1 className="text-2xl font-bold tracking-tight text-gray-900">
              Change Password
            </h1>
          </div>
          {error && (
            <Alert variant="destructive">
              <AlertDescription>{error}</AlertDescription>
            </Alert>
          )}
          <ResetPasswordForm token={token} />
        </div>
      </AuthLayout>
    </>
  );
}

ResetPassword.layout = (page: React.ReactNode) => (
  <AuthProvider>{page}</AuthProvider>
);
