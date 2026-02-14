import { Link } from "@inertiajs/react";
import { User, ChevronRight, BadgeCheck } from "lucide-react";

interface SellerCardProps {
  seller: {
    id: string;
    email: string;
    fullName: string | null;
    username?: string | null;
  } | null;
}

export function SellerCard({ seller }: SellerCardProps) {
  if (!seller) return null;

  const displayName = seller.fullName || seller.email;
  const storeUrl = `/store/${seller.username || seller.id}`;

  return (
    <div className="rounded-2xl bg-neutral-08 p-4 lg:p-5">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          {/* Avatar placeholder */}
          <div className="flex size-10 shrink-0 items-center justify-center rounded-full bg-neutral-06 lg:size-12">
            <User className="size-5 text-neutral-04 lg:size-6" />
          </div>
          <div>
            <div className="flex items-center gap-1.5">
              <span className="text-sm font-medium text-neutral-01 lg:text-base">
                {displayName}
              </span>
              <BadgeCheck className="size-4 text-primary-600" />
            </div>
            <p className="text-xs text-neutral-04">Seller</p>
          </div>
        </div>

        {/* Visit seller store */}
        <Link
          href={storeUrl}
          className="flex size-9 items-center justify-center rounded-full border border-neutral-06 transition-colors hover:bg-neutral-07"
        >
          <ChevronRight className="size-4 text-neutral-03" />
        </Link>
      </div>
    </div>
  );
}
