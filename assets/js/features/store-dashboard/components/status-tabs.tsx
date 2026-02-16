import { cn } from "@/lib/utils";

interface StatusTabsProps {
  current: string;
  perPage: number;
  onNavigate: (params: Record<string, string | number>) => void;
}

const STATUS_TABS = [
  { key: "all", label: "All" },
  { key: "active", label: "Active" },
  { key: "ended", label: "Ended" },
  { key: "draft", label: "Draft" },
] as const;

export function StatusTabs({ current, perPage, onNavigate }: StatusTabsProps) {
  return (
    <div className="mb-4 flex gap-2">
      {STATUS_TABS.map((tab) => (
        <button
          key={tab.key}
          type="button"
          onClick={() => onNavigate({ status: tab.key, page: 1, per_page: perPage })}
          className={cn(
            "rounded-full px-4 py-1.5 text-sm font-medium transition-colors",
            current === tab.key
              ? "bg-primary-600 text-white"
              : "bg-surface-secondary text-content-secondary hover:bg-surface-muted"
          )}
        >
          {tab.label}
        </button>
      ))}
    </div>
  );
}
