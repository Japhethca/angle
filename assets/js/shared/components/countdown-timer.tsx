import { useState, useEffect } from "react";
import { Clock } from "lucide-react";
import { cn } from "@/lib/utils";

interface CountdownTimerProps {
  endTime: string;
  className?: string;
}

function getTimeRemaining(endTime: string) {
  const total = new Date(endTime).getTime() - Date.now();
  if (total <= 0) return null;

  const days = Math.floor(total / (1000 * 60 * 60 * 24));
  const hours = Math.floor((total / (1000 * 60 * 60)) % 24);
  const minutes = Math.floor((total / (1000 * 60)) % 60);

  return { days, hours, minutes };
}

export function CountdownTimer({ endTime, className }: CountdownTimerProps) {
  const [remaining, setRemaining] = useState(() => getTimeRemaining(endTime));

  useEffect(() => {
    const interval = setInterval(() => {
      setRemaining(getTimeRemaining(endTime));
    }, 60_000);

    return () => clearInterval(interval);
  }, [endTime]);

  if (!remaining) {
    return (
      <span className={cn("inline-flex items-center gap-1 text-xs text-content-tertiary", className)}>
        <Clock className="size-3" />
        Ended
      </span>
    );
  }

  return (
    <span className={cn("inline-flex items-center gap-1 text-xs text-content-tertiary", className)}>
      <Clock className="size-3" />
      {remaining.days}d {remaining.hours}h {remaining.minutes}m
    </span>
  );
}
