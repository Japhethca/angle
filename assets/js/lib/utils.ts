import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatCurrency(
  value: number | string | null | undefined,
  currency: string = "NGN"
): string {
  if (value === null || value === undefined) {
    return "₦0.00";
  }

  const numValue = typeof value === "string" ? parseFloat(value) : value;

  if (isNaN(numValue)) {
    return "₦0.00";
  }

  // Format with Nigerian Naira currency
  return new Intl.NumberFormat("en-NG", {
    style: "currency",
    currency: currency,
  }).format(numValue);
}
