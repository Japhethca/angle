import { Link } from "@inertiajs/react";
import { Gavel, CircleCheck, History, Headset } from "lucide-react";
import { Section } from "@/components/layout/section";
import { cn } from "@/lib/utils";

interface BidsLayoutProps {
  tab: string;
  children: React.ReactNode;
}

const tabs = [
  { label: "Active", value: "active", icon: Gavel },
  { label: "Won", value: "won", icon: CircleCheck },
  { label: "History", value: "history", icon: History },
];

export function BidsLayout({ tab, children }: BidsLayoutProps) {
  return (
    <>
      {/* Mobile: horizontal tabs */}
      <div className="border-b border-default lg:hidden">
        <div className="flex">
          {tabs.map((t) => (
            <Link
              key={t.value}
              href={`/bids?tab=${t.value}`}
              className={cn(
                "flex-1 py-3 text-center text-sm font-medium transition-colors",
                tab === t.value
                  ? "border-b-2 border-content text-content"
                  : "text-content-tertiary"
              )}
            >
              {t.label}
            </Link>
          ))}
        </div>
      </div>

      {/* Desktop: sidebar + content */}
      <Section className="hidden lg:flex lg:min-h-[calc(100vh-88px)] lg:gap-10 lg:py-6">
        <aside className="flex w-[160px] shrink-0 flex-col justify-between">
          <nav className="space-y-1">
            {tabs.map((t) => {
              const isActive = tab === t.value;
              return (
                <Link
                  key={t.value}
                  href={`/bids?tab=${t.value}`}
                  className={cn(
                    "flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors",
                    isActive
                      ? "bg-primary-600/10 text-primary-600"
                      : "text-content-tertiary hover:text-content"
                  )}
                >
                  <t.icon className="size-5" />
                  {t.label}
                </Link>
              );
            })}
          </nav>
          <Link
            href="/settings/support"
            className="flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium text-content-tertiary hover:text-content"
          >
            <Headset className="size-5" />
            Support
          </Link>
        </aside>

        <div className="min-w-0 flex-1">
          <div className="mb-6 flex items-center gap-2">
            <h1 className="text-xl font-bold text-content">
              {tabs.find((t) => t.value === tab)?.label}
            </h1>
          </div>
          {children}
        </div>
      </Section>

      {/* Mobile: content */}
      <div className="px-4 pb-6 pt-4 lg:hidden">{children}</div>
    </>
  );
}
