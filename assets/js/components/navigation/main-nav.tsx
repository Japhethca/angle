import { Link } from "@inertiajs/react";
import { useAuth } from "../../contexts/auth-context";
import { LogoutButton } from "../auth/logout-button";
import { PermissionGuard, AdminOnly, CanCreateItems, CanPlaceBids, CanManageUsers } from "../auth/permission-guard";

export function MainNav() {
  const { authenticated, user, hasRole, hasPermission } = useAuth();
  console.log("MainNav Debug:", {
    authenticated,
    user,
    userRoles: user?.roles,
    userPermissions: user?.permissions,
    canCreateItems: hasPermission("create_items"),
    isAdmin: hasRole("admin")
  });

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

                {/* Catalog - visible to all authenticated users */}
                <PermissionGuard permission="read_catalog">
                  <Link
                    href="/catalog"
                    className="text-gray-600 hover:text-gray-900 px-3 py-2 rounded-md"
                  >
                    Catalog
                  </Link>
                </PermissionGuard>

                {/* Items - visible to sellers and admins */}
                <CanCreateItems>
                  <Link
                    href="/items"
                    className="text-gray-600 hover:text-gray-900 px-3 py-2 rounded-md"
                  >
                    My Items
                  </Link>
                </CanCreateItems>

                {/* Bidding - visible to bidders */}
                <CanPlaceBids>
                  <Link
                    href="/bids"
                    className="text-gray-600 hover:text-gray-900 px-3 py-2 rounded-md"
                  >
                    My Bids
                  </Link>
                </CanPlaceBids>

                {/* Admin Panel - admin only */}
                <AdminOnly>
                  <Link
                    href="/admin"
                    className="text-gray-600 hover:text-gray-900 px-3 py-2 rounded-md"
                  >
                    Admin
                  </Link>
                </AdminOnly>

                {/* User Management - admin only */}
                <CanManageUsers>
                  <Link
                    href="/users"
                    className="text-gray-600 hover:text-gray-900 px-3 py-2 rounded-md"
                  >
                    Users
                  </Link>
                </CanManageUsers>

                {/* Developer Dashboard - admin only in production */}
                <AdminOnly>
                  <a
                    href="/dev/dashboard"
                    className="text-gray-600 hover:text-gray-900 px-3 py-2 rounded-md"
                  >
                    Dev Tools
                  </a>
                </AdminOnly>

                <Link
                  href="/profile"
                  className="text-gray-600 hover:text-gray-900 px-3 py-2 rounded-md"
                >
                  Profile
                </Link>
              </div>
            )}
          </div>

          <div className="flex items-center space-x-4">
            {/* Debug Auth State */}
            <div className="text-xs bg-gray-100 p-2 rounded">
              <div>Auth: {authenticated ? "✅ Logged In" : "❌ Not Logged In"}</div>
              {user && (
                <>
                  <div>Email: {user.email}</div>
                  <div>Roles: {user.roles?.join(", ") || "None"}</div>
                  <div>Permissions: {user.permissions?.length || 0}</div>
                </>
              )}
            </div>

            {authenticated ? (
              <>
                <div className="text-sm text-gray-600">
                  <div>{user?.email}</div>
                  {user?.roles && user.roles.length > 0 && (
                    <div className="text-xs text-gray-500">
                      {user.roles.join(", ")}
                    </div>
                  )}
                </div>
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
