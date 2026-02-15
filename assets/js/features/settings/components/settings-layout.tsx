import { Link, usePage } from "@inertiajs/react";
import { router } from "@inertiajs/react";
import { ArrowLeft, ChevronRight } from "lucide-react";
import { cn } from "@/lib/utils";

const settingsMenuItems = [
  { label: "Account", href: "/settings/account" },
  { label: "Store", href: "#", disabled: true },
  { label: "Security", href: "#", disabled: true },
  { label: "Payments", href: "#", disabled: true },
  { label: "Notifications", href: "#", disabled: true },
  { label: "Preferences", href: "#", disabled: true },
  { label: "Legal", href: "#", disabled: true },
  { label: "Support", href: "#", disabled: true },
];

interface SettingsLayoutProps {
  title: string;
  children: React.ReactNode;
}

export function SettingsLayout({ title, children }: SettingsLayoutProps) {
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
                    "block rounded-lg px-3 py-2.5 text-sm font-medium transition-colors",
                    isActive
                      ? "bg-neutral-08 text-neutral-01"
                      : "text-neutral-04 hover:text-neutral-02",
                    item.disabled && "cursor-not-allowed opacity-50"
                  )}
                  onClick={(e) => {
                    if (item.disabled) e.preventDefault();
                  }}
                >
                  {item.label}
                </Link>
              );
            })}
          </nav>

          <button
            onClick={handleLogout}
            className="mt-6 block w-full rounded-lg px-3 py-2.5 text-left text-sm font-medium text-red-500 transition-colors hover:bg-red-50"
          >
            Log Out
          </button>
        </aside>

        {/* Content area */}
        <div className="min-w-0 flex-1">
          {/* Breadcrumb */}
          <nav className="mb-6 flex items-center gap-1.5 text-xs text-neutral-04">
            <span>Settings</span>
            <ChevronRight className="size-3" />
            <span className="text-neutral-02">{title}</span>
          </nav>

          {children}
        </div>
      </div>

      {/* Mobile: content */}
      <div className="px-4 pb-6 lg:hidden">{children}</div>
    </>
  );
}
