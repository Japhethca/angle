import { Link } from "@inertiajs/react";

export function EmptyWatchlist() {
  return (
    <div className="flex min-h-[70vh] flex-col items-center justify-center px-4">
      <img
        src="/images/empty-watchlist.svg"
        alt=""
        className="mb-6 h-48 w-auto"
      />

      <h2 className="text-lg font-semibold text-content">
        Your Watchlist is empty.
      </h2>
      <p className="mt-2 hidden max-w-md text-center text-sm text-content-tertiary sm:block">
        Save items you like to compare prices, monitor bids, or bid for later.
      </p>
      <Link
        href="/"
        className="mt-6 rounded-full border-[1.2px] border-content px-6 py-3 text-sm font-medium text-content transition-colors hover:bg-surface-muted"
      >
        Browse Items
      </Link>
    </div>
  );
}
