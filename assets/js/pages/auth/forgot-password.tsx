import { Head, usePage } from '@inertiajs/react';
import { ForgotPasswordForm } from '../../components/forms/forgot-password-form';
import { PageProps } from '../../types/auth';

interface ForgotPasswordPageProps extends PageProps {
  error?: string;
}

export default function ForgotPassword() {
  const { props } = usePage<ForgotPasswordPageProps>();
  const { error } = props;

  return (
    <>
      <Head title="Reset Password" />
      <div className="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
        <div className="max-w-md w-full space-y-8">
          <div className="text-center">
            <h1 className="text-3xl font-bold text-gray-900">Angle</h1>
            <p className="mt-2 text-sm text-gray-600">Reset your password</p>
          </div>
          <ForgotPasswordForm error={error} />
        </div>
      </div>
    </>
  );
}