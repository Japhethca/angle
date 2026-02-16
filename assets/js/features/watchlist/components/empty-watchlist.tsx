import { Link } from "@inertiajs/react";

export function EmptyWatchlist() {
  return (
    <div className="flex min-h-[50vh] flex-col items-center justify-center px-4">
      {/* Illustration placeholder */}
      <div className="mb-6 h-48 w-48 rounded-lg bg-surface-muted" />

      <h2 className="text-lg font-semibold text-content">
        Your Watchlist is empty.
      </h2>
      <p className="mt-2 max-w-md text-center text-sm text-content-tertiary">
        Save items you like to compare prices, monitor bids, or bid for later.
      </p>
      <Link
        href="/"
        className="mt-6 rounded-lg border border-strong px-6 py-2.5 text-sm font-medium text-content transition-colors hover:bg-surface-muted"
      >
        Browse Items
      </Link>
    </div>
  );
}
