import { Head, Link, router } from "@inertiajs/react";
import { Eye, Heart, Gavel, Banknote, Plus, Package } from "lucide-react";
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
}

function navigate(params: Record<string, string | number>) {
  const query = Object.fromEntries(
    Object.entries(params).filter(
      ([k, v]) =>
        !(k === "status" && v === "all") &&
        !(k === "page" && v === 1) &&
        !(k === "per_page" && v === 10)
    )
  );
  router.get("/store/listings", query, { preserveState: true, preserveScroll: false });
}

export default function StoreListings({
  items = [],
  stats,
  pagination,
  status = "all",
}: StoreListingsProps) {
  const defaultStats: Stats = {
    total_views: 0,
    total_watches: 0,
    total_bids: 0,
    total_amount: "0",
  };
  const s = stats || defaultStats;
  const p = pagination || { page: 1, per_page: 10, total: 0, total_pages: 1 };

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

          {/* Status filter tabs */}
          <StatusTabs current={status} perPage={p.per_page} onNavigate={navigate} />

          {items.length > 0 ? (
            <>
              {/* Desktop table */}
              <div className="hidden lg:block">
                <div className="rounded-xl border border-surface-muted bg-white">
                  <ListingTable items={items} />
                  <PaginationControls pagination={p} status={status} onNavigate={navigate} />
                </div>
              </div>

              {/* Mobile cards */}
              <div className="flex flex-col gap-3 lg:hidden">
                {items.map((item) => (
                  <ListingCard key={item.id} item={item} />
                ))}
                <PaginationControls pagination={p} status={status} onNavigate={navigate} />
              </div>
            </>
          ) : (
            <div className="flex flex-col items-center justify-center rounded-xl border border-surface-muted bg-white py-16 text-center">
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
