import { Link, usePage } from "@inertiajs/react";
import {
  Package,
  Wallet,
  Store,
  HelpCircle,
  ChevronRight,
} from "lucide-react";
import { cn } from "@/lib/utils";

const navItems = [
  { label: "Listings", href: "/store/listings", icon: Package },
  { label: "Payments", href: "/store/payments", icon: Wallet },
  { label: "Store Profile", href: "/store/profile", icon: Store },
];

interface StoreLayoutProps {
  title: string;
  children: React.ReactNode;
}

export function StoreLayout({ title, children }: StoreLayoutProps) {
  const { url } = usePage();

  return (
    <>
      {/* Mobile: horizontal pill tabs */}
      <div className="px-4 pt-4 lg:hidden">
        <div className="rounded-lg border border-surface-muted bg-surface-secondary p-1">
          <div className="flex">
            {navItems.map((item) => {
              const isActive = url.startsWith(item.href);
              return (
                <Link
                  key={item.label}
                  href={item.href}
                  className={cn(
                    "flex-1 rounded-md px-3 py-2 text-center text-sm font-medium transition-colors",
                    isActive
                      ? "bg-white text-content shadow-sm"
                      : "text-content-tertiary",
                  )}
                >
                  {item.label}
                </Link>
              );
            })}
          </div>
        </div>
      </div>

      {/* Desktop: sidebar + content */}
      <div className="hidden lg:flex lg:gap-10 lg:px-10 lg:py-6">
        {/* Sidebar */}
        <aside className="w-[240px] shrink-0">
          <nav className="space-y-1">
            {navItems.map((item) => {
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

          <Link
            href="/settings/support"
            className="mt-6 flex w-full items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium text-content-tertiary transition-colors hover:text-content"
          >
            <HelpCircle className="size-5" />
            Support
          </Link>
        </aside>

        {/* Content area */}
        <div className="min-w-0 flex-1">
          {/* Breadcrumb */}
          <nav className="mb-6 flex items-center gap-1.5 text-xs text-content-tertiary">
            <span>Store</span>
            <ChevronRight className="size-3" />
            <span className="text-content">{title}</span>
          </nav>

          {children}
        </div>
      </div>

      {/* Mobile: content */}
      <div className="px-4 pb-6 pt-4 lg:hidden">{children}</div>
    </>
  );
}
