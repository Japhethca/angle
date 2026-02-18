import { Sun, Moon, Monitor } from "lucide-react";
import { useTheme, type ThemeOption } from "@/hooks/use-theme";
import { cn } from "@/lib/utils";

const options: { value: ThemeOption; icon: typeof Sun; label: string }[] = [
  { value: "light", icon: Sun, label: "Light" },
  { value: "system", icon: Monitor, label: "System" },
  { value: "dark", icon: Moon, label: "Dark" },
];

interface ThemeToggleProps {
  className?: string;
}

export function ThemeToggle({ className }: ThemeToggleProps) {
  const { theme, setTheme } = useTheme();

  return (
    <div
      className={cn(
        "inline-flex items-center rounded-full bg-surface-muted p-1",
        className
      )}
    >
      {options.map(({ value, icon: Icon, label }) => (
        <button
          key={value}
          type="button"
          onClick={() => setTheme(value)}
          className={cn(
            "flex items-center gap-1.5 rounded-full px-3 py-1.5 text-xs font-medium transition-colors",
            theme === value
              ? "bg-surface text-content shadow-sm"
              : "text-content-tertiary hover:text-content-secondary"
          )}
        >
          <Icon className="size-3.5" />
          {label}
        </button>
      ))}
    </div>
  );
}
