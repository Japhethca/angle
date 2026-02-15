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
  { label: "Notifications", href: "/settings/notifications", icon: Bell },
  { label: "Preferences", href: "/settings/preferences", icon: SlidersHorizontal },
  { label: "Legal", href: "/settings/legal", icon: Scale },
  { label: "Support", href: "/settings/support", icon: HelpCircle },
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
          className="flex size-9 items-center justify-center rounded-full border border-strong"
        >
          <ArrowLeft className="size-4 text-content" />
        </Link>
        <h1 className="text-base font-semibold text-content">{title}</h1>
      </div>

      {/* Desktop: sidebar + content */}
      <div className="hidden lg:flex lg:gap-10 lg:px-10 lg:py-6">
        {/* Sidebar */}
        <aside className="w-[240px] shrink-0">
          <nav className="space-y-1">
            {settingsMenuItems.map((item) => {
              const isActive = url.startsWith(item.href);
              return (
                <Link
                  key={item.label}
                  href={item.href}
                  className={cn(
                    "flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors",
                    isActive
                      ? "bg-primary-600/10 text-primary-600"
                      : "text-content-tertiary hover:text-content",
                  )}
                >
                  <item.icon className="size-5" />
                  {item.label}
                </Link>
              );
            })}
          </nav>

          <button
            onClick={handleLogout}
            className="mt-6 flex w-full items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium text-feedback-error transition-colors hover:bg-feedback-error-muted"
          >
            <LogOut className="size-5" />
            Log Out
          </button>
        </aside>

        {/* Content area */}
        <div className="min-w-0 max-w-2xl flex-1">
          {/* Breadcrumb */}
          <nav className="mb-6 flex items-center gap-1.5 text-xs text-content-tertiary">
            <span>Settings</span>
            <ChevronRight className="size-3" />
            <span className={breadcrumbSuffix ? "" : "text-content"}>{title}</span>
            {breadcrumbSuffix && (
              <>
                <ChevronRight className="size-3" />
                <span className="text-content">{breadcrumbSuffix}</span>
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
