import { cn } from "@/lib/utils";

interface ThemeCardProps {
  variant: "light" | "dark" | "system";
  selected: boolean;
  onClick: () => void;
}

export function ThemeCard({ variant, selected, onClick }: ThemeCardProps) {
  const isLight = variant === "light" || variant === "system";
  const isSystem = variant === "system";

  return (
    <button type="button" onClick={onClick} className="flex flex-1 flex-col items-center gap-2">
      <div
        className={cn(
          "w-full rounded-lg border-2 p-1",
          selected ? "border-content" : "border-subtle"
        )}
      >
        <div
          className={cn(
            "flex flex-col gap-2 rounded p-2",
            isSystem
              ? "bg-gradient-to-r from-neutral-07 to-neutral-01"
              : isLight
                ? "bg-neutral-07"
                : "bg-neutral-01"
          )}
        >
          <div
            className={cn(
              "flex flex-col gap-2 rounded-md p-2 shadow-sm",
              isSystem
                ? "bg-gradient-to-r from-white to-neutral-03"
                : isLight
                  ? "bg-white"
                  : "bg-neutral-03"
            )}
          >
            <div className={cn("h-2 w-20 rounded-full", isLight ? "bg-neutral-07" : "bg-neutral-04")} />
            <div className={cn("h-2 w-[100px] rounded-full", isLight ? "bg-neutral-07" : "bg-neutral-04")} />
          </div>
          {[1, 2].map((i) => (
            <div
              key={i}
              className={cn(
                "flex items-center gap-2 rounded-md p-2 shadow-sm",
                isSystem
                  ? "bg-gradient-to-r from-white to-neutral-03"
                  : isLight
                    ? "bg-white"
                    : "bg-neutral-03"
              )}
            >
              <div className={cn("size-4 rounded-full", isLight ? "bg-neutral-07" : "bg-neutral-04")} />
              <div className={cn("h-2 w-[100px] rounded-full", isLight ? "bg-neutral-07" : "bg-neutral-04")} />
            </div>
          ))}
        </div>
      </div>
      <span className="text-sm text-content-secondary">
        {variant === "light" ? "Light" : variant === "dark" ? "Dark" : "System"}
      </span>
    </button>
  );
}
