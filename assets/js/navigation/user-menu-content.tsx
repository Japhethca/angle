import { Link, router } from "@inertiajs/react";
import { ChevronRight, LogOut } from "lucide-react";
import { useAuth } from "@/features/auth";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";

interface UserMenuContentProps {
  onNavigate?: () => void;
}

function getInitials(name: string | null): string {
  if (!name) return "?";
  const parts = name.trim().split(" ").filter(Boolean);
  if (parts.length === 0) return "?";
  return parts
    .map((n) => n[0])
    .join("")
    .toUpperCase()
    .slice(0, 2);
}

export function UserMenuContent({ onNavigate }: UserMenuContentProps) {
  const { user } = useAuth();
  if (!user) return null;

  return (
    <div className="flex flex-col gap-10">
      {/* User details */}
      <div className="flex flex-col items-center gap-2">
        <Avatar className="size-20">
          <AvatarFallback className="bg-[#ffe7cc] text-2xl font-medium text-[#a34400]">
            {getInitials(user.full_name)}
          </AvatarFallback>
        </Avatar>
        <div className="flex flex-col items-center gap-1">
          <p className="text-xl text-content">{user.full_name}</p>
          <p className="text-sm text-content-tertiary">{user.email}</p>
        </div>
      </div>

      {/* Actions */}
      <div className="flex flex-col gap-4">
        <Link
          href="/settings/account"
          className="flex items-center justify-between text-base text-content transition-colors hover:text-content-secondary"
          onClick={onNavigate}
        >
          Settings
          <ChevronRight className="size-5" />
        </Link>
        <button
          type="button"
          className="flex w-full items-center justify-between text-base text-content-tertiary transition-colors hover:text-content-secondary"
          onClick={() => {
            onNavigate?.();
            router.post("/auth/logout");
          }}
        >
          Log out
          <LogOut className="size-5" />
        </button>
      </div>
    </div>
  );
}
