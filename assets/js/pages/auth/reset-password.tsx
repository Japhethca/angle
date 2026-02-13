import React from "react";
import { Head, usePage } from "@inertiajs/react";
import { ResetPasswordForm, AuthProvider } from "@/features/auth";
import type { PageProps } from "@/features/auth";
import { AuthLayout } from "@/layouts/auth-layout";
import { Alert, AlertDescription } from "@/components/ui/alert";

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
