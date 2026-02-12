export function formatNaira(amount: number | string): string {
  const num = typeof amount === "string" ? parseFloat(amount) : amount;
  return `\u20A6${num.toLocaleString("en-NG", { minimumFractionDigits: 0, maximumFractionDigits: 0 })}`;
}
