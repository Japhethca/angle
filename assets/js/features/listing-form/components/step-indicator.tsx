import { Check } from "lucide-react";
import { cn } from "@/lib/utils";

const STEPS = [
  { number: 1, label: "Basic Details" },
  { number: 2, label: "Auction Info" },
  { number: 3, label: "Logistics" },
] as const;

interface StepIndicatorProps {
  currentStep: number;
}

export function StepIndicator({ currentStep }: StepIndicatorProps) {
  return (
    <>
      {/* Desktop: small dots with inline labels connected by lines */}
      <div className="hidden md:flex items-center gap-0">
        {STEPS.map((step, index) => {
          const isCompleted = currentStep > step.number;
          const isActive = currentStep === step.number;
          const isLast = index === STEPS.length - 1;

          return (
            <div key={step.number} className="flex items-center">
              {/* Dot + label */}
              <div className="flex items-center gap-2">
                <div
                  className={cn(
                    "flex size-3.5 shrink-0 items-center justify-center rounded-full transition-colors",
                    isCompleted
                      ? "bg-feedback-success"
                      : isActive
                        ? "bg-content"
                        : "border-2 border-content-tertiary/40 bg-transparent"
                  )}
                >
                  {isCompleted && <Check className="size-2.5 text-white" />}
                </div>
                <span
                  className={cn(
                    "text-sm font-medium whitespace-nowrap",
                    isActive || isCompleted ? "text-content" : "text-content-tertiary"
                  )}
                >
                  {step.label}
                </span>
              </div>

              {/* Connecting line */}
              {!isLast && (
                <div className="mx-3 w-20 shrink-0">
                  <div
                    className={cn(
                      "h-px",
                      isCompleted ? "bg-feedback-success" : "bg-content-tertiary/30"
                    )}
                  />
                </div>
              )}
            </div>
          );
        })}
      </div>

      {/* Mobile: progress bar */}
      <div className="md:hidden">
        <div className="flex gap-1.5">
          {[1, 2, 3].map((step) => (
            <div
              key={step}
              className={cn(
                "h-1 flex-1 rounded-full transition-colors",
                step <= currentStep ? "bg-primary-600" : "bg-surface-muted"
              )}
            />
          ))}
        </div>
      </div>
    </>
  );
}
