import { Head, usePage } from '@inertiajs/react';
import { ResetPasswordForm } from '../../components/forms/reset-password-form';
import { PageProps } from '../../types/auth';

interface ResetPasswordPageProps extends PageProps {
  token: string;
  error?: string;
}

export default function ResetPassword() {
  const { props } = usePage<ResetPasswordPageProps>();
  const { token, error } = props;

  return (
    <>
      <Head title="Set New Password" />
      <div className="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
        <div className="max-w-md w-full space-y-8">
          <div className="text-center">
            <h1 className="text-3xl font-bold text-gray-900">Angle</h1>
            <p className="mt-2 text-sm text-gray-600">Set your new password</p>
          </div>
          <ResetPasswordForm token={token} error={error} />
        </div>
      </div>
    </>
  );
}