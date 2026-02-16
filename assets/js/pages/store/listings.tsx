import { useEffect, useRef, useState } from "react";
import { Head, Link, router } from "@inertiajs/react";
import { Eye, Heart, Gavel, Banknote, Plus, Package, Loader2 } from "lucide-react";
import type { SellerDashboardCard } from "@/ash_rpc";
import {
  StoreLayout,
  StatsCard,
  ListingTable,
  ListingCard,
  StatusTabs,
  PaginationControls,
} from "@/features/store-dashboard";
import { formatCurrency } from "@/features/store-dashboard/utils";

type Item = SellerDashboardCard[number];

interface Stats {
  total_views: number;
  total_watches: number;
  total_bids: number;
  total_amount: string;
}

interface Pagination {
  page: number;
  per_page: number;
  total: number;
  total_pages: number;
}

interface StoreListingsProps {
  items: Item[];
  stats: Stats;
  pagination: Pagination;
  status: string;
  sort: string;
  dir: string;
}

function navigate(params: Record<string, string | number>) {
  const query = Object.fromEntries(
    Object.entries(params).filter(
      ([k, v]) =>
        !(k === "status" && v === "all") &&
        !(k === "page" && v === 1) &&
        !(k === "per_page" && v === 10) &&
        !(k === "sort" && v === "inserted_at") &&
        !(k === "dir" && v === "desc")
    )
  );
  router.get("/store/listings", query, { preserveState: true, preserveScroll: false });
}

export default function StoreListings({
  items = [],
  stats,
  pagination,
  status = "all",
  sort = "inserted_at",
  dir = "desc",
}: StoreListingsProps) {
  const defaultStats: Stats = {
    total_views: 0,
    total_watches: 0,
    total_bids: 0,
    total_amount: "0",
  };
  const s = stats || defaultStats;
  const p = pagination || { page: 1, per_page: 10, total: 0, total_pages: 1 };

  // Mobile "Load More" state
  const [mobileItems, setMobileItems] = useState<Item[]>(items);
  const [mobileLoading, setMobileLoading] = useState(false);
  const prevStatusRef = useRef(status);

  useEffect(() => {
    if (status !== prevStatusRef.current) {
      // Filter changed — reset
      setMobileItems(items);
      prevStatusRef.current = status;
    } else if (p.page === 1) {
      // Initial load or filter reset
      setMobileItems(items);
    } else {
      // Load more — append new items, deduplicating by ID
      setMobileItems((prev) => {
        const existingIds = new Set(prev.map((i) => i.id));
        const newItems = items.filter((i) => !existingIds.has(i.id));
        return [...prev, ...newItems];
      });
    }
    setMobileLoading(false);
  }, [items, p.page, status]);

  function loadMore() {
    setMobileLoading(true);
    const query = Object.fromEntries(
      Object.entries({
        status,
        sort,
        dir,
        page: p.page + 1,
        per_page: p.per_page,
      }).filter(
        ([k, v]) =>
          !(k === "status" && v === "all") &&
          !(k === "page" && v === 1) &&
          !(k === "per_page" && v === 10) &&
          !(k === "sort" && v === "inserted_at") &&
          !(k === "dir" && v === "desc")
      )
    );
    router.get("/store/listings", query, {
      preserveState: true,
      preserveScroll: true,
      replace: true,
      only: ["items", "pagination"],
    });
  }

  const hasMore = p.page < p.total_pages;

  return (
    <>
      <Head title="Store - Listings" />
      <StoreLayout title="Listings">
        {/* Stats grid */}
        <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
          <StatsCard label="Views" value={s.total_views} icon={Eye} />
          <StatsCard label="Watch" value={s.total_watches} icon={Heart} />
          <StatsCard label="Bids" value={s.total_bids} icon={Gavel} />
          <StatsCard label="Amount" value={formatCurrency(s.total_amount)} icon={Banknote} />
        </div>

        {/* Item listings section */}
        <div className="mt-8">
          <div className="mb-4 flex items-center justify-between">
            <h2 className="text-lg font-semibold text-content">
              Item Listings
            </h2>
            <Link
              href="/items/new"
              className="hidden items-center gap-2 rounded-full bg-primary-600 px-5 py-2 text-sm font-medium text-white transition-colors hover:bg-primary-700 lg:inline-flex"
            >
              <Plus className="size-4" />
              List Item
            </Link>
          </div>

          {/* Status filter tabs (mobile only — desktop uses column header dropdown) */}
          <div className="lg:hidden">
            <StatusTabs current={status} perPage={p.per_page} onNavigate={navigate} />
          </div>

          {/* Desktop table (always show headers for sort/filter access) */}
          <div className="hidden lg:block">
            <div className="rounded-xl border border-surface-muted bg-white">
              <ListingTable items={items} sort={sort} dir={dir} status={status} perPage={p.per_page} onNavigate={navigate} />
              {items.length > 0 && (
                <PaginationControls pagination={p} status={status} sort={sort} dir={dir} onNavigate={navigate} />
              )}
            </div>
          </div>

          {/* Mobile cards with Load More */}
          {mobileItems.length > 0 ? (
            <div className="flex flex-col gap-3 lg:hidden">
              {mobileItems.map((item) => (
                <ListingCard key={item.id} item={item} />
              ))}
              {hasMore && (
                <button
                  type="button"
                  onClick={loadMore}
                  disabled={mobileLoading}
                  className="mt-1 flex w-full items-center justify-center gap-2 rounded-xl border border-surface-muted bg-white py-3 text-sm font-medium text-content-secondary transition-colors hover:bg-surface-secondary disabled:opacity-50"
                >
                  {mobileLoading ? (
                    <>
                      <Loader2 className="size-4 animate-spin" />
                      Loading...
                    </>
                  ) : (
                    "Load More"
                  )}
                </button>
              )}
              <p className="text-center text-xs text-content-placeholder">
                Showing {mobileItems.length} of {p.total} items
              </p>
            </div>
          ) : (
            <div className="flex flex-col items-center justify-center rounded-xl border border-surface-muted bg-white py-16 text-center lg:hidden">
              <Package className="mb-3 size-12 text-surface-emphasis" />
              <p className="text-lg text-content-tertiary">No listings yet</p>
              <p className="mt-1 text-sm text-content-placeholder">
                {status === "all"
                  ? "Create your first listing to start selling"
                  : `No ${status} listings found`}
              </p>
            </div>
          )}
        </div>

        {/* Mobile FAB */}
        <Link
          href="/items/new"
          className="fixed bottom-20 right-4 z-20 flex size-14 items-center justify-center rounded-full bg-primary-600 text-white shadow-lg transition-transform hover:scale-105 lg:hidden"
        >
          <Plus className="size-6" />
        </Link>
      </StoreLayout>
    </>
  );
}
