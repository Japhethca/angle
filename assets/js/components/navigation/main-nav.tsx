import { Link } from "@inertiajs/react";
import { useAuth } from "../../contexts/auth-context";
import { LogoutButton } from "../auth/logout-button";

export function MainNav() {
  const { authenticated, user } = useAuth();
  console.log("MainNav user:", user, authenticated);

  return (
    <nav className="bg-white shadow">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between h-16">
          <div className="flex items-center">
            <Link href="/" className="text-xl font-bold text-gray-900">
              Angle
            </Link>

            {authenticated && (
              <div className="ml-8 flex space-x-4">
                <Link
                  href="/dashboard"
                  className="text-gray-600 hover:text-gray-900 px-3 py-2 rounded-md"
                >
                  Dashboard
                </Link>
                <Link
                  href="/profile"
                  className="text-gray-600 hover:text-gray-900 px-3 py-2 rounded-md"
                >
                  Profile
                </Link>
                <a
                  href="/dev/dashboard"
                  className="text-gray-600 hover:text-gray-900 px-3 py-2 rounded-md"
                >
                  Developer Dashboard
                </a>
              </div>
            )}
          </div>

          <div className="flex items-center space-x-4">
            {authenticated ? (
              <>
                <span className="text-sm text-gray-600">{user?.email}</span>
                <LogoutButton />
              </>
            ) : (
              <>
                <Link
                  href="/auth/login"
                  className="text-gray-600 hover:text-gray-900"
                >
                  Sign In
                </Link>
                <Link
                  href="/auth/register"
                  className="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700"
                >
                  Sign Up
                </Link>
              </>
            )}
          </div>
        </div>
      </div>
    </nav>
  );
}
