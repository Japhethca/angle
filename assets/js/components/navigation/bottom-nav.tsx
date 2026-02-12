import { Link, usePage } from "@inertiajs/react";
import { Home, Gavel, Heart, Store, Settings } from "lucide-react";
import { cn } from "@/lib/utils";

const tabs = [
  { label: "Home", href: "/", icon: Home },
  { label: "Bids", href: "/bids", icon: Gavel },
  { label: "Watchlist", href: "/watchlist", icon: Heart },
  { label: "Sell", href: "/items/new", icon: Store },
  { label: "Settings", href: "/settings", icon: Settings },
];

export function BottomNav() {
  const { url } = usePage();

  const isActive = (href: string) => {
    if (href === "/") return url === "/";
    return url.startsWith(href);
  };

  return (
    <nav className="fixed bottom-0 left-0 right-0 z-40 border-t border-neutral-07 bg-white lg:hidden">
      <div className="flex h-[72px] items-center justify-around px-4">
        {tabs.map((tab) => {
          const active = isActive(tab.href);
          const Icon = tab.icon;
          return (
            <Link
              key={tab.href}
              href={tab.href}
              className={cn(
                "flex flex-col items-center gap-1 px-3 py-2 text-[10px]",
                active ? "text-primary-600" : "text-neutral-04"
              )}
            >
              <Icon className="size-5" strokeWidth={active ? 2.5 : 2} />
              <span className={cn("font-medium", active && "font-semibold")}>
                {tab.label}
              </span>
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
