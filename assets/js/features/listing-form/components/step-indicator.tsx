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
      {/* Desktop: tab-style */}
      <div className="hidden md:flex items-center gap-1 border-b border-border">
        {STEPS.map((step) => {
          const isCompleted = currentStep > step.number;
          const isActive = currentStep === step.number || (currentStep === 4 && step.number === 3);
          return (
            <button
              key={step.number}
              type="button"
              disabled
              className={cn(
                "flex items-center gap-2 px-4 py-3 text-sm font-medium border-b-2 -mb-px transition-colors",
                isActive
                  ? "border-primary-600 text-primary-600"
                  : isCompleted
                    ? "border-transparent text-content-secondary"
                    : "border-transparent text-content-tertiary"
              )}
            >
              {isCompleted && <Check className="size-4 text-feedback-success" />}
              {step.label}
            </button>
          );
        })}
      </div>

      {/* Mobile: progress bar */}
      <div className="md:hidden">
        <div className="flex gap-1.5">
          {[1, 2, 3, 4].map((step) => (
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
