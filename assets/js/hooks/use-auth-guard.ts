import { router } from "@inertiajs/react";
import { useAuth } from "@/contexts/auth-context";

/**
 * Hook for imperative auth-guarded navigation.
 * If authenticated, navigates to the given href.
 * If not, redirects to login with return_to set.
 */
export function useAuthGuard() {
  const { authenticated } = useAuth();

  const guard = (href: string) => {
    if (authenticated) {
      router.visit(href);
    } else {
      router.visit(`/auth/login?return_to=${encodeURIComponent(href)}`);
    }
  };

  return { guard, authenticated };
}
