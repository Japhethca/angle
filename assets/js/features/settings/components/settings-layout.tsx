import { Link, usePage } from "@inertiajs/react";
import { router } from "@inertiajs/react";
import {
  ArrowLeft,
  ChevronRight,
  User,
  Store,
  Shield,
  CreditCard,
  Bell,
  SlidersHorizontal,
  Scale,
  HelpCircle,
  LogOut,
} from "lucide-react";
import { cn } from "@/lib/utils";

const settingsMenuItems = [
  { label: "Account", href: "/settings/account", icon: User },
  { label: "Store", href: "/settings/store", icon: Store },
  { label: "Security", href: "/settings/security", icon: Shield },
  { label: "Payments", href: "/settings/payments", icon: CreditCard },
  { label: "Notifications", href: "#", disabled: true, icon: Bell },
  { label: "Preferences", href: "#", disabled: true, icon: SlidersHorizontal },
  { label: "Legal", href: "#", disabled: true, icon: Scale },
  { label: "Support", href: "#", disabled: true, icon: HelpCircle },
];

interface SettingsLayoutProps {
  title: string;
  breadcrumbSuffix?: string;
  children: React.ReactNode;
}

export function SettingsLayout({ title, breadcrumbSuffix, children }: SettingsLayoutProps) {
  const { url } = usePage();

  const handleLogout = () => {
    router.post("/auth/logout");
  };

  return (
    <>
      {/* Mobile: back arrow + title */}
      <div className="flex items-center gap-3 px-4 py-3 lg:hidden">
        <Link
          href="/settings"
          className="flex size-9 items-center justify-center rounded-full border border-neutral-06"
        >
          <ArrowLeft className="size-4 text-neutral-02" />
        </Link>
        <h1 className="text-base font-semibold text-neutral-01">{title}</h1>
      </div>

      {/* Desktop: sidebar + content */}
      <div className="hidden lg:flex lg:gap-10 lg:px-10 lg:py-6">
        {/* Sidebar */}
        <aside className="w-[240px] shrink-0">
          <nav className="space-y-1">
            {settingsMenuItems.map((item) => {
              const isActive = url.startsWith(item.href) && !item.disabled;
              return (
                <Link
                  key={item.label}
                  href={item.disabled ? "#" : item.href}
                  className={cn(
                    "flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors",
                    isActive
                      ? "bg-primary-600/10 text-primary-600"
                      : "text-neutral-04 hover:text-neutral-02",
                    item.disabled && "cursor-not-allowed"
                  )}
                  onClick={(e) => {
                    if (item.disabled) e.preventDefault();
                  }}
                >
                  <item.icon className="size-5" />
                  {item.label}
                </Link>
              );
            })}
          </nav>

          <button
            onClick={handleLogout}
            className="mt-6 flex w-full items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium text-red-500 transition-colors hover:bg-red-50"
          >
            <LogOut className="size-5" />
            Log Out
          </button>
        </aside>

        {/* Content area */}
        <div className="min-w-0 max-w-2xl flex-1">
          {/* Breadcrumb */}
          <nav className="mb-6 flex items-center gap-1.5 text-xs text-neutral-04">
            <span>Settings</span>
            <ChevronRight className="size-3" />
            <span className={breadcrumbSuffix ? "" : "text-neutral-02"}>{title}</span>
            {breadcrumbSuffix && (
              <>
                <ChevronRight className="size-3" />
                <span className="text-neutral-02">{breadcrumbSuffix}</span>
              </>
            )}
          </nav>

          {children}
        </div>
      </div>

      {/* Mobile: content */}
      <div className="px-4 pb-6 lg:hidden">{children}</div>
    </>
  );
}
