import type { LucideIcon } from "lucide-react";

interface StatsCardProps {
  label: string;
  value: string | number;
  icon: LucideIcon;
}

export function StatsCard({ label, value, icon: Icon }: StatsCardProps) {
  return (
    <div className="rounded-xl border border-surface-muted bg-white p-4">
      <div className="flex items-center justify-between">
        <span className="text-sm text-content-tertiary">{label}</span>
        <Icon className="size-5 text-content-placeholder" />
      </div>
      <p className="mt-2 text-2xl font-semibold text-content">{value}</p>
    </div>
  );
}
