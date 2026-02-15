import { Head } from "@inertiajs/react";
import { ProtectedRoute, CanManageUsers, usePermissions } from "@/features/auth";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";

interface User {
  id: string;
  email: string;
  confirmed_at: string | null;
  roles: string[];
}

interface UsersPageProps {
  users: User[];
}

export default function UsersPage({ users }: UsersPageProps) {
  const { hasPermission } = usePermissions();

  return (
    <ProtectedRoute permission="manage_users" fallback={
      <div className="min-h-screen bg-surface-muted flex items-center justify-center">
        <Card className="w-96">
          <CardHeader>
            <CardTitle>Access Denied</CardTitle>
            <CardDescription>
              You don't have permission to manage users.
            </CardDescription>
          </CardHeader>
        </Card>
      </div>
    }>
      <div className="min-h-screen bg-surface-muted">
        <Head title="User Management" />
        
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <div className="md:flex md:items-center md:justify-between">
            <div className="flex-1 min-w-0">
              <h2 className="text-2xl font-bold leading-7 text-content sm:text-3xl sm:truncate">
                User Management
              </h2>
              <p className="mt-1 text-sm text-content-tertiary">
                Manage user accounts and role assignments
              </p>
            </div>
            
            <div className="mt-4 flex md:mt-0 md:ml-4">
              <CanManageUsers>
                <Button>
                  Create User
                </Button>
              </CanManageUsers>
            </div>
          </div>

          <div className="mt-8">
            <Card>
              <CardHeader>
                <CardTitle>Users</CardTitle>
                <CardDescription>
                  All registered users and their roles
                </CardDescription>
              </CardHeader>
              <CardContent>
                <div className="overflow-x-auto">
                  <table className="min-w-full divide-y divide-subtle">
                    <thead className="bg-surface-muted">
                      <tr>
                        <th className="px-6 py-3 text-left text-xs font-medium text-content-tertiary uppercase tracking-wider">
                          User
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-content-tertiary uppercase tracking-wider">
                          Status
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-content-tertiary uppercase tracking-wider">
                          Roles
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-content-tertiary uppercase tracking-wider">
                          Actions
                        </th>
                      </tr>
                    </thead>
                    <tbody className="bg-surface divide-y divide-subtle">
                      {users?.map((user) => (
                        <tr key={user.id}>
                          <td className="px-6 py-4 whitespace-nowrap">
                            <div className="text-sm font-medium text-content">
                              {user.email}
                            </div>
                            <div className="text-sm text-content-tertiary">
                              ID: {user.id}
                            </div>
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap">
                            <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${
                              user.confirmed_at
                                ? 'bg-feedback-success-muted text-feedback-success'
                                : 'bg-feedback-warning-muted text-feedback-warning'
                            }`}>
                              {user.confirmed_at ? 'Active' : 'Pending'}
                            </span>
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap">
                            <div className="flex flex-wrap gap-1">
                              {user.roles?.map((role) => (
                                <span
                                  key={role}
                                  className="inline-flex px-2 py-1 text-xs font-medium rounded bg-feedback-info-muted text-feedback-info"
                                >
                                  {role}
                                </span>
                              )) || (
                                <span className="text-sm text-content-placeholder">No roles</span>
                              )}
                            </div>
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                            <CanManageUsers>
                              <div className="flex space-x-2">
                                <Button variant="outline" size="sm">
                                  Edit Roles
                                </Button>
                                {hasPermission("manage_permissions") && (
                                  <Button variant="outline" size="sm">
                                    Permissions
                                  </Button>
                                )}
                              </div>
                            </CanManageUsers>
                          </td>
                        </tr>
                      ))}
                      {(!users || users.length === 0) && (
                        <tr>
                          <td colSpan={4} className="px-6 py-4 text-center text-content-tertiary">
                            No users found
                          </td>
                        </tr>
                      )}
                    </tbody>
                  </table>
                </div>
              </CardContent>
            </Card>
          </div>
        </div>
      </div>
    </ProtectedRoute>
  );
}