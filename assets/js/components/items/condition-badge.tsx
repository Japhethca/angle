import { cn } from "@/lib/utils";

const conditionLabels: Record<string, string> = {
  new: "New",
  used: "Fairly used",
  refurbished: "Refurbished",
};

interface ConditionBadgeProps {
  condition: string | null;
  className?: string;
}

export function ConditionBadge({ condition, className }: ConditionBadgeProps) {
  if (!condition) return null;

  return (
    <span
      className={cn(
        "inline-block rounded-full bg-[rgba(253,224,204,0.4)] px-4 py-1 text-[10px] font-medium text-primary-800",
        className
      )}
    >
      {conditionLabels[condition] || condition}
    </span>
  );
}
