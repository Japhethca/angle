import type { SellerProfile, SellerItemCard } from "@/ash_rpc";

type Seller = SellerProfile[number];
type SellerItem = SellerItemCard[number];

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
  active_tab: string;
}

export default function StoreShow({
  seller,
  items,
  has_more: _hasMore,
  category_summary: _categorySummary,
  active_tab: _activeTab,
}: StoreShowProps) {
  return (
    <div className="container mx-auto px-4 py-8">
      <div className="mb-8">
        <h1 className="text-2xl font-bold">
          {seller.storeName || seller.fullName}
        </h1>
        {seller.location && (
          <p className="text-muted-foreground">{seller.location}</p>
        )}
      </div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {items.map((item) => (
          <div key={item.id} className="rounded-lg border p-4">
            <h3 className="font-medium">{item.title}</h3>
          </div>
        ))}
      </div>
    </div>
  );
}
