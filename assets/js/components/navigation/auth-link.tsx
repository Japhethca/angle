import { Link, type InertiaLinkProps } from "@inertiajs/react";
import { useAuth } from "@/contexts/auth-context";

interface AuthLinkProps extends InertiaLinkProps {
  auth?: boolean;
}

/**
 * Drop-in replacement for Inertia <Link>.
 * When `auth` is true and user is not authenticated,
 * clicking redirects to login with return_to set.
 */
export function AuthLink({ auth, href, ...props }: AuthLinkProps) {
  const { authenticated } = useAuth();

  const resolvedHref =
    auth && !authenticated
      ? `/auth/login?return_to=${encodeURIComponent(href as string)}`
      : href;

  return <Link {...props} href={resolvedHref} />;
}
