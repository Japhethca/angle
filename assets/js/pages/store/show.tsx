import { useState, useCallback } from "react";
import { Head, Link } from "@inertiajs/react";
import {
  ChevronLeft,
  User,
  BadgeCheck,
  MapPin,
  Phone,
  MessageCircle,
  LayoutGrid,
  List,
  Loader2,
  Star,
  UserPlus,
  Share2,
} from "lucide-react";
import { toast } from "sonner";
import type { SellerProfile, SellerItemCard } from "@/ash_rpc";
import { listItems, sellerItemCardFields, buildCSRFHeaders } from "@/ash_rpc";
import type { ListItemsFields } from "@/ash_rpc";
import { CategoryItemCard, CategoryItemListCard } from "@/features/items";
import type { CategoryItem } from "@/features/items";

type Seller = SellerProfile[number];
type SellerItem = SellerItemCard[number];

type ViewMode = "grid" | "list";
type TabKey = "auctions" | "history" | "reviews";

interface CategorySummary {
  id: string;
  name: string;
  slug: string;
  count: number;
}

interface StoreShowProps {
  seller: Seller;
  items: SellerItem[];
  has_more: boolean;
  category_summary: CategorySummary[];
  active_tab: TabKey;
}

const ITEMS_PER_PAGE = 20;
const VIEW_MODE_KEY = "store-view-mode";

function getInitialViewMode(): ViewMode {
  if (typeof window === "undefined") return "grid";
  const stored = localStorage.getItem(VIEW_MODE_KEY);
  return stored === "list" ? "list" : "grid";
}

function formatJoinDate(dateStr: string): string {
  const date = new Date(dateStr);
  return date.toLocaleDateString("en-US", {
    month: "long",
    year: "numeric",
  });
}

export default function StoreShow({
  seller,
  items: initialItems = [],
  has_more: initialHasMore = false,
  category_summary: categorySummary = [],
  active_tab: initialActiveTab = "auctions",
}: StoreShowProps) {
  const displayName = seller.storeProfile?.storeName || seller.fullName || "Store";
  const storeUrl = `/store/${seller.username || seller.id}`;

  const [activeTab, setActiveTab] = useState<TabKey>(initialActiveTab);
  const [viewMode, setViewMode] = useState<ViewMode>(getInitialViewMode);

  // Route server-loaded items to the correct tab state
  const auctionTabActive = initialActiveTab === "auctions";
  const historyTabActive = initialActiveTab === "history";

  // Auctions tab state (server-loaded when active_tab is auctions)
  const [auctionItems, setAuctionItems] =
    useState<SellerItem[]>(auctionTabActive ? initialItems : []);
  const [auctionHasMore, setAuctionHasMore] = useState(auctionTabActive ? initialHasMore : false);
  const [isLoadingMoreAuctions, setIsLoadingMoreAuctions] = useState(false);

  // History tab state (server-loaded when active_tab is history, otherwise client-loaded on demand)
  const [historyItems, setHistoryItems] = useState<SellerItem[]>(historyTabActive ? initialItems : []);
  const [historyHasMore, setHistoryHasMore] = useState(historyTabActive ? initialHasMore : false);
  const [isLoadingHistory, setIsLoadingHistory] = useState(false);
  const [isLoadingMoreHistory, setIsLoadingMoreHistory] = useState(false);
  const [historyLoaded, setHistoryLoaded] = useState(historyTabActive);

  const handleViewModeChange = (mode: ViewMode) => {
    setViewMode(mode);
    localStorage.setItem(VIEW_MODE_KEY, mode);
  };

  const handleShareStore = async () => {
    const url = new URL(storeUrl, window.location.origin);
    if (activeTab !== "auctions") {
      url.searchParams.set("tab", activeTab);
    }
    try {
      await navigator.clipboard.writeText(url.toString());
      toast.success("Store link copied to clipboard");
    } catch {
      toast.error("Failed to copy link");
    }
  };

  const loadMoreAuctions = useCallback(async () => {
    if (isLoadingMoreAuctions) return;
    setIsLoadingMoreAuctions(true);
    try {
      const fields = sellerItemCardFields as ListItemsFields;
      const result = await listItems({
        fields,
        filter: {
          createdById: { eq: seller.id },
          publicationStatus: { eq: "published" },
          auctionStatus: { in: ["pending", "scheduled", "active"] },
        },
        page: { limit: ITEMS_PER_PAGE, offset: auctionItems.length },
        headers: buildCSRFHeaders(),
      });

      if (result.success && result.data) {
        const data = result.data as {
          results: SellerItem[];
          hasMore: boolean;
        };
        setAuctionItems((prev) => [...prev, ...data.results]);
        setAuctionHasMore(data.hasMore);
      }
    } finally {
      setIsLoadingMoreAuctions(false);
    }
  }, [seller.id, auctionItems.length, isLoadingMoreAuctions]);

  const loadHistory = useCallback(async () => {
    if (isLoadingHistory) return;
    setIsLoadingHistory(true);
    try {
      const fields = sellerItemCardFields as ListItemsFields;
      const result = await listItems({
        fields,
        filter: {
          createdById: { eq: seller.id },
          publicationStatus: { eq: "published" },
          auctionStatus: { in: ["ended", "sold"] },
        },
        page: { limit: ITEMS_PER_PAGE, offset: 0 },
        headers: buildCSRFHeaders(),
      });

      if (result.success && result.data) {
        const data = result.data as {
          results: SellerItem[];
          hasMore: boolean;
        };
        setHistoryItems(data.results);
        setHistoryHasMore(data.hasMore);
        setHistoryLoaded(true);
      }
    } finally {
      setIsLoadingHistory(false);
    }
  }, [seller.id, isLoadingHistory]);

  // NOTE: Uses listItems with inline filters for client-side load-more.
  // The server-side initial load uses the by_seller typed query via the controller.
  // If the by_seller filter logic changes, these filters must be updated to match.
  const loadMoreHistory = useCallback(async () => {
    if (isLoadingMoreHistory) return;
    setIsLoadingMoreHistory(true);
    try {
      const fields = sellerItemCardFields as ListItemsFields;
      const result = await listItems({
        fields,
        filter: {
          createdById: { eq: seller.id },
          publicationStatus: { eq: "published" },
          auctionStatus: { in: ["ended", "sold"] },
        },
        page: { limit: ITEMS_PER_PAGE, offset: historyItems.length },
        headers: buildCSRFHeaders(),
      });

      if (result.success && result.data) {
        const data = result.data as {
          results: SellerItem[];
          hasMore: boolean;
        };
        setHistoryItems((prev) => [...prev, ...data.results]);
        setHistoryHasMore(data.hasMore);
      }
    } finally {
      setIsLoadingMoreHistory(false);
    }
  }, [seller.id, historyItems.length, isLoadingMoreHistory]);

  const handleTabChange = (tab: TabKey) => {
    setActiveTab(tab);
    if (tab === "history" && !historyLoaded) {
      loadHistory();
    }

    // Update URL to reflect the active tab
    const url = new URL(window.location.href);
    if (tab === "auctions") {
      url.searchParams.delete("tab");
    } else {
      url.searchParams.set("tab", tab);
    }
    window.history.replaceState({}, "", url.toString());
  };

  // Determine which items and load-more to show for the current tab
  const currentItems =
    activeTab === "auctions" ? auctionItems : historyItems;
  const currentHasMore =
    activeTab === "auctions" ? auctionHasMore : historyHasMore;
  const currentIsLoading =
    activeTab === "auctions" ? isLoadingMoreAuctions : isLoadingMoreHistory;
  const currentLoadMore =
    activeTab === "auctions" ? loadMoreAuctions : loadMoreHistory;

  const tabs: { key: TabKey; label: string }[] = [
    { key: "auctions", label: "Auctions" },
    { key: "history", label: "History" },
    { key: "reviews", label: "Reviews" },
  ];

  return (
    <>
      <Head title={`${displayName} - Store Profile`} />
    <div className="pb-8">
      {/* Mobile header */}
      <div className="flex items-center gap-3 px-4 py-4 lg:hidden">
        <Link
          href="/"
          className="flex size-9 items-center justify-center"
        >
          <ChevronLeft className="size-5 text-neutral-01" />
        </Link>
        <h1 className="text-xl font-medium text-neutral-01">
          Store Profile
        </h1>
      </div>

      {/* Desktop breadcrumb */}
      <div className="hidden px-10 pt-8 lg:block">
        <nav className="mb-6 text-sm text-neutral-04">
          <Link href="/" className="hover:text-neutral-01">
            Home
          </Link>
          <span className="mx-2">/</span>
          <span className="text-neutral-01">Store Profile</span>
        </nav>
      </div>

      {/* Seller Header */}
      <div className="px-4 lg:px-10">
        <div className="flex flex-col gap-6 lg:flex-row lg:items-start lg:justify-between">
          {/* Seller info */}
          <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:gap-6">
            {/* Avatar */}
            <div className="flex size-20 shrink-0 items-center justify-center rounded-full bg-neutral-08">
              <User className="size-10 text-neutral-05" />
            </div>

            <div className="space-y-3">
              {/* Name + badge */}
              <div className="flex items-center gap-2">
                <h2 className="text-2xl font-semibold text-neutral-01">
                  {displayName}
                </h2>
                <BadgeCheck className="size-5 text-primary-600" />
              </div>

              {/* Stats row (placeholders) */}
              <div className="flex items-center gap-4 text-sm text-neutral-04">
                <span className="flex items-center gap-1">
                  <Star className="size-4 text-yellow-500" />
                  <span className="font-medium">4.8</span>
                  <span className="text-neutral-05">(120 reviews)</span>
                </span>
                <span className="text-neutral-06">|</span>
                <span>{auctionItems.length}+ listings</span>
              </div>

              {/* Join date */}
              <p className="text-sm text-neutral-05">
                Joined {formatJoinDate(seller.createdAt)}
              </p>

              {/* Contact info */}
              <div className="flex flex-wrap items-center gap-x-4 gap-y-2 text-sm text-neutral-04">
                {seller.location && (
                  <span className="flex items-center gap-1.5">
                    <MapPin className="size-4 text-neutral-05" />
                    {seller.location}
                  </span>
                )}
                {seller.phoneNumber && (
                  <span className="flex items-center gap-1.5">
                    <Phone className="size-4 text-neutral-05" />
                    {seller.phoneNumber}
                  </span>
                )}
                {seller.whatsappNumber && (
                  <span className="flex items-center gap-1.5">
                    <MessageCircle className="size-4 text-neutral-05" />
                    {seller.whatsappNumber}
                  </span>
                )}
              </div>

              {/* Category chips */}
              {categorySummary.length > 0 && (
                <div className="flex flex-wrap gap-2 pt-1">
                  {categorySummary.map((cat) => (
                    <span
                      key={cat.id}
                      className="rounded-lg border border-neutral-08 bg-neutral-09 px-3 py-1 text-xs text-neutral-03"
                    >
                      {cat.name}{" "}
                      <span className="text-neutral-05">({cat.count})</span>
                    </span>
                  ))}
                </div>
              )}
            </div>
          </div>

          {/* Action buttons */}
          <div className="flex shrink-0 items-center gap-3">
            <button
              className="flex items-center gap-2 rounded-full border border-neutral-06 px-5 py-2.5 text-sm font-medium text-neutral-03 transition-colors hover:bg-neutral-09"
              onClick={() => {
                /* Follow placeholder */
              }}
            >
              <UserPlus className="size-4" />
              Follow
            </button>
            <button
              onClick={handleShareStore}
              className="flex items-center gap-2 rounded-full border border-neutral-06 px-5 py-2.5 text-sm font-medium text-neutral-03 transition-colors hover:bg-neutral-09"
            >
              <Share2 className="size-4" />
              Share
            </button>
          </div>
        </div>
      </div>

      {/* Tabs + view toggle */}
      <div className="mt-8 flex items-center justify-between border-b border-neutral-08 px-4 lg:px-10">
        <div className="flex">
          {tabs.map((tab) => (
            <button
              key={tab.key}
              onClick={() => handleTabChange(tab.key)}
              className={`relative px-5 py-3 text-sm font-medium transition-colors ${
                activeTab === tab.key
                  ? "text-primary-600"
                  : "text-neutral-04 hover:text-neutral-02"
              }`}
            >
              {tab.label}
              {activeTab === tab.key && (
                <span className="absolute bottom-0 left-0 right-0 h-0.5 bg-primary-600" />
              )}
            </button>
          ))}
        </div>

        {/* View toggle */}
        {activeTab !== "reviews" && (
          <div className="flex shrink-0 items-center gap-1">
            <button
              onClick={() => handleViewModeChange("grid")}
              aria-label="Grid view"
              className={`flex size-8 items-center justify-center rounded transition-colors ${
                viewMode === "grid"
                  ? "text-primary-600"
                  : "text-neutral-05 hover:text-neutral-03"
              }`}
            >
              <LayoutGrid className="size-4" />
            </button>
            <button
              onClick={() => handleViewModeChange("list")}
              aria-label="List view"
              className={`flex size-8 items-center justify-center rounded transition-colors ${
                viewMode === "list"
                  ? "text-primary-600"
                  : "text-neutral-05 hover:text-neutral-03"
              }`}
            >
              <List className="size-4" />
            </button>
          </div>
        )}
      </div>

      {/* Tab content */}
      <div className="mt-6">
        {activeTab === "reviews" ? (
          /* Reviews placeholder */
          <div className="flex flex-col items-center justify-center px-4 py-16 text-center">
            <Star className="mb-3 size-12 text-neutral-06" />
            <p className="text-lg text-neutral-04">No reviews yet</p>
            <p className="mt-1 text-sm text-neutral-05">
              Reviews will appear here once buyers leave feedback
            </p>
          </div>
        ) : (
          <>
            {/* Loading state for history initial load */}
            {activeTab === "history" && isLoadingHistory && !historyLoaded ? (
              <div className="flex items-center justify-center py-16">
                <Loader2 className="size-6 animate-spin text-neutral-04" />
              </div>
            ) : currentItems.length > 0 ? (
              <>
                {viewMode === "grid" ? (
                  <div className="grid grid-cols-2 gap-4 px-4 sm:gap-6 lg:grid-cols-4 lg:px-10">
                    {currentItems.map((item) => (
                      <CategoryItemCard
                        key={item.id}
                        item={item as CategoryItem}
                      />
                    ))}
                  </div>
                ) : (
                  <div className="flex flex-col gap-4 px-4 lg:px-10">
                    {currentItems.map((item) => (
                      <CategoryItemListCard
                        key={item.id}
                        item={item as CategoryItem}
                      />
                    ))}
                  </div>
                )}

                {/* Load More button */}
                {currentHasMore && (
                  <div className="flex justify-center px-4 pt-8 lg:px-10">
                    <button
                      onClick={currentLoadMore}
                      disabled={currentIsLoading}
                      className="flex items-center gap-2 rounded-full border border-neutral-06 px-8 py-3 text-sm font-medium text-neutral-03 transition-colors hover:bg-neutral-09 disabled:opacity-50"
                    >
                      {currentIsLoading ? (
                        <>
                          <Loader2 className="size-4 animate-spin" />
                          Loading...
                        </>
                      ) : (
                        "Load More"
                      )}
                    </button>
                  </div>
                )}
              </>
            ) : (
              <div className="flex flex-col items-center justify-center px-4 py-16 text-center">
                <p className="text-lg text-neutral-04">
                  {activeTab === "auctions"
                    ? "No active auctions"
                    : "No past auctions"}
                </p>
                <p className="mt-1 text-sm text-neutral-05">
                  {activeTab === "auctions"
                    ? "This seller has no active listings right now"
                    : "This seller has no completed auctions yet"}
                </p>
              </div>
            )}
          </>
        )}
      </div>
    </div>
    </>
  );
}
