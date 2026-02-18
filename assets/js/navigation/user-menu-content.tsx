import { Link, router } from "@inertiajs/react";
import { ChevronRight, LogOut, User, Store, CreditCard } from "lucide-react";
import { useAuth } from "@/features/auth";
import { Avatar, AvatarImage, AvatarFallback } from "@/components/ui/avatar";
import { ThemeToggle } from "@/components/theme-toggle";

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

const menuItems = [
  { label: "Account", href: "/settings/account", icon: User },
  { label: "Store", href: "/store", icon: Store },
  { label: "Payments", href: "/settings/payments", icon: CreditCard },
];

export function UserMenuContent({ onNavigate }: UserMenuContentProps) {
  const { user } = useAuth();
  if (!user) return null;

  return (
    <div className="flex flex-col gap-6">
      {/* User details */}
      <div className="flex flex-col items-center gap-2">
        <Avatar className="size-20">
          {user.avatar_url && (
            <AvatarImage src={user.avatar_url} alt="" />
          )}
          <AvatarFallback className="bg-[#ffe7cc] text-2xl font-medium text-[#a34400]">
            {getInitials(user.full_name)}
          </AvatarFallback>
        </Avatar>
        <div className="flex flex-col items-center gap-1">
          <p className="text-xl text-content">{user.full_name}</p>
          <p className="text-sm text-content-tertiary">{user.email}</p>
        </div>
      </div>

      {/* Theme toggle */}
      <div className="flex justify-center">
        <ThemeToggle />
      </div>

      {/* Navigation links */}
      <div className="flex flex-col gap-4">
        {menuItems.map(({ label, href, icon: Icon }) => (
          <Link
            key={href}
            href={href}
            className="flex items-center justify-between text-base text-content transition-colors hover:text-content-secondary"
            onClick={onNavigate}
          >
            <span className="flex items-center gap-3">
              <Icon className="size-5 text-content-tertiary" />
              {label}
            </span>
            <ChevronRight className="size-5 text-content-tertiary" />
          </Link>
        ))}
      </div>

      {/* Log out */}
      <button
        type="button"
        className="flex w-full items-center justify-between text-base text-content-tertiary transition-colors hover:text-content-secondary"
        onClick={() => {
          onNavigate?.();
          router.post("/auth/logout");
        }}
      >
        <span className="flex items-center gap-3">
          <LogOut className="size-5" />
          Log out
        </span>
      </button>
    </div>
  );
}
