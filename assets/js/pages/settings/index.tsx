import { useEffect } from "react";
import { Head, Link, router } from "@inertiajs/react";
import { User, ChevronRight, Shield, CreditCard, Bell, SlidersHorizontal, Scale, HelpCircle, LogOut } from "lucide-react";
import { useMediaQuery } from "@/hooks/use-media-query";

interface SettingsUser {
  id: string;
  email: string;
  full_name: string | null;
  phone_number: string | null;
  location: string | null;
}

interface SettingsIndexProps {
  user: SettingsUser;
}

const menuItems = [
  { label: "Security", icon: Shield, disabled: true },
  { label: "Payments", icon: CreditCard, disabled: true },
  { label: "Notifications", icon: Bell, disabled: true },
  { label: "Preferences", icon: SlidersHorizontal, disabled: true },
  { label: "Legal", icon: Scale, disabled: true },
  { label: "Support", icon: HelpCircle, disabled: true },
];

export default function SettingsIndex({ user }: SettingsIndexProps) {
  const isDesktop = useMediaQuery("(min-width: 1024px)");

  // Desktop: redirect to account page
  useEffect(() => {
    if (isDesktop) {
      router.visit("/settings/account", { replace: true });
    }
  }, [isDesktop]);

  const handleLogout = () => {
    router.post("/auth/logout");
  };

  return (
    <>
      <Head title="Settings" />

      <div className="px-4 py-4 lg:hidden">
        <h1 className="mb-4 text-lg font-semibold text-neutral-01">Settings</h1>

        {/* Profile card */}
        <Link
          href="/settings/account"
          className="mb-4 flex items-center gap-3 rounded-2xl bg-neutral-08 p-4"
        >
          <div className="flex size-12 shrink-0 items-center justify-center rounded-full bg-neutral-06">
            <User className="size-6 text-neutral-04" />
          </div>
          <div className="min-w-0 flex-1">
            <div className="flex items-center gap-1">
              <p className="truncate text-sm font-medium text-neutral-01">
                {user.full_name || "Set up your profile"}
              </p>
              <ChevronRight className="size-4 shrink-0 text-neutral-04" />
            </div>
            <p className="truncate text-xs text-neutral-04">{user.email}</p>
          </div>
        </Link>

        {/* Menu items */}
        <div className="space-y-1">
          {menuItems.map((item) => (
            <div
              key={item.label}
              className="flex items-center justify-between rounded-lg px-3 py-3 text-neutral-04 opacity-50"
            >
              <div className="flex items-center gap-3">
                <item.icon className="size-5" />
                <span className="text-sm font-medium">{item.label}</span>
              </div>
              <ChevronRight className="size-4" />
            </div>
          ))}
        </div>

        {/* Log Out */}
        <button
          onClick={handleLogout}
          className="mt-6 flex w-full items-center gap-3 rounded-lg px-3 py-3 text-red-500"
        >
          <LogOut className="size-5" />
          <span className="text-sm font-medium">Log Out</span>
        </button>
      </div>
    </>
  );
}
