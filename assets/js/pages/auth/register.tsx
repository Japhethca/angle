import { Head, usePage } from '@inertiajs/react';
import { RegisterForm } from '../../components/forms/register-form';
import { PageProps } from '../../types/auth';

interface RegisterPageProps extends PageProps {
  error?: string;
}

export default function Register() {
  const { props } = usePage<RegisterPageProps>();
  const { error } = props;

  return (
    <>
      <Head title="Sign Up" />
      <div className="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
        <div className="max-w-md w-full space-y-8">
          <div className="text-center">
            <h1 className="text-3xl font-bold text-gray-900">Angle</h1>
            <p className="mt-2 text-sm text-gray-600">Create your account</p>
          </div>
          <RegisterForm error={error} />
        </div>
      </div>
    </>
  );
}