export function formatCurrency(value: string | number | null | undefined): string {
  if (value == null) return "\u20A60";
  const num = typeof value === "string" ? parseFloat(value) : value;
  if (isNaN(num)) return "\u20A60";
  return (
    "\u20A6" +
    num.toLocaleString("en-NG", {
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    })
  );
}

export function formatDate(dateStr: string | null | undefined): string {
  if (!dateStr) return "--";
  const date = new Date(dateStr);
  const day = String(date.getDate()).padStart(2, "0");
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const year = String(date.getFullYear()).slice(2);
  return `${day}/${month}/${year}`;
}
