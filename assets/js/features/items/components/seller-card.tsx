import { Link } from "@inertiajs/react";
import { User, ArrowRight, BadgeCheck, Star } from "lucide-react";

interface SellerCardProps {
  seller: {
    id: string;
    fullName: string | null;
    username?: string | null;
    publishedItemCount?: number | null;
    storeProfile?: {
      storeName?: string | null;
    } | null;
  } | null;
}

export function SellerCard({ seller }: SellerCardProps) {
  if (!seller) return null;

  const displayName = seller.storeProfile?.storeName || seller.fullName || seller.username || "Seller";
  const storeUrl = `/store/${seller.username || seller.id}`;
  const itemCount = seller.publishedItemCount;

  return (
    <div className="rounded-2xl bg-surface-muted p-4 lg:p-5">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          {/* Avatar placeholder */}
          <div className="flex size-10 shrink-0 items-center justify-center rounded-full bg-surface-emphasis lg:size-12">
            <User className="size-5 text-content-tertiary lg:size-6" />
          </div>
          <div>
            <div className="flex items-center gap-1.5">
              <span className="text-sm font-medium text-content lg:text-base">
                {displayName}
                {itemCount != null && itemCount > 0 && (
                  <span className="text-content-tertiary"> ({itemCount})</span>
                )}
              </span>
              <BadgeCheck className="size-4 text-primary-600" />
            </div>
            <div className="flex items-center gap-1 text-xs text-content-tertiary">
              <Star className="size-3 fill-current text-amber-500" />
              <span>5</span>
              <span>·</span>
              <span>95%</span>
              <span>·</span>
              <span>117 Reviews</span>
            </div>
          </div>
        </div>

        {/* Visit seller store */}
        <Link
          href={storeUrl}
          className="flex size-9 items-center justify-center rounded-full bg-content transition-opacity hover:opacity-80"
        >
          <ArrowRight className="size-4 text-white" />
        </Link>
      </div>
    </div>
  );
}
