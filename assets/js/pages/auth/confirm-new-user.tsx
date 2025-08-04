import { Head, Link } from '@inertiajs/react';
import { PageProps } from '../../types/auth';

interface ConfirmNewUserProps extends PageProps {
  error?: boolean;
  message?: string;
}

export default function ConfirmNewUser({ error = false, message }: ConfirmNewUserProps) {
  return (
    <>
      <Head title="Account Confirmation" />
      <div className="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
        <div className="max-w-md w-full space-y-8">
          <div>
            <div className="mx-auto h-12 w-12 flex items-center justify-center">
              {error ? (
                <svg 
                  className="h-12 w-12 text-red-600" 
                  fill="none" 
                  stroke="currentColor" 
                  viewBox="0 0 24 24"
                >
                  <path 
                    strokeLinecap="round" 
                    strokeLinejoin="round" 
                    strokeWidth="2" 
                    d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" 
                  />
                </svg>
              ) : (
                <svg 
                  className="h-12 w-12 text-green-600" 
                  fill="none" 
                  stroke="currentColor" 
                  viewBox="0 0 24 24"
                >
                  <path 
                    strokeLinecap="round" 
                    strokeLinejoin="round" 
                    strokeWidth="2" 
                    d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" 
                  />
                </svg>
              )}
            </div>
            <h2 className="mt-6 text-center text-3xl font-extrabold text-gray-900">
              {error ? 'Confirmation Failed' : 'Processing Confirmation'}
            </h2>
            {message && (
              <p className={`mt-2 text-center text-sm ${error ? 'text-red-600' : 'text-gray-600'}`}>
                {message}
              </p>
            )}
          </div>

          {error ? (
            <div className="rounded-md bg-red-50 p-4">
              <div className="text-sm text-red-700">
                <p className="mb-4">
                  The confirmation link you used is invalid or has expired. This could happen if:
                </p>
                <ul className="list-disc list-inside space-y-1 mb-4">
                  <li>The link is more than 24 hours old</li>
                  <li>You've already confirmed your account</li>
                  <li>The link was corrupted when copying</li>
                </ul>
                <p>Please try registering again to receive a new confirmation email.</p>
              </div>
              
              <div className="mt-6 flex space-x-4">
                <Link
                  href="/auth/register"
                  className="flex-1 inline-flex justify-center items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-red-600 hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500"
                >
                  Register Again
                </Link>
                <Link
                  href="/auth/login"
                  className="flex-1 inline-flex justify-center items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                >
                  Sign In
                </Link>
              </div>
            </div>
          ) : (
            <div className="rounded-md bg-blue-50 p-4">
              <div className="text-sm text-blue-700">
                <p>Please wait while we confirm your account...</p>
                <div className="mt-4 flex justify-center">
                  <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-blue-600"></div>
                </div>
              </div>
            </div>
          )}

          <div className="text-center">
            <Link
              href="/"
              className="text-sm text-blue-600 hover:text-blue-500"
            >
              ← Back to home
            </Link>
          </div>
        </div>
      </div>
    </>
  );
}