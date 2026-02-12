import { Link } from "@inertiajs/react";
import { Eye, Gavel } from "lucide-react";
import type { HomepageItemCard } from "@/ash_rpc";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { CountdownTimer } from "@/components/shared/countdown-timer";
import { formatNaira } from "@/lib/format";
import { cn } from "@/lib/utils";

type ItemCardItem = HomepageItemCard[number];

interface ItemCardProps {
  item: ItemCardItem;
  badge?: "ending-soon" | "hot-now" | "almost-gone";
}

const badgeLabels: Record<string, { label: string; className: string }> = {
  "ending-soon": { label: "Ending Soon", className: "bg-feedback-error text-white border-transparent" },
  "hot-now": { label: "Hot Now", className: "bg-primary-600 text-white border-transparent" },
  "almost-gone": { label: "Almost Gone", className: "bg-primary-1000 text-white border-transparent" },
};

export function ItemCard({ item, badge }: ItemCardProps) {
  const itemUrl = `/items/${item.slug || item.id}`;
  const price = item.currentPrice || item.startingPrice;

  return (
    <Card className="w-[280px] shrink-0 overflow-hidden border-neutral-07">
      <div className="relative aspect-[4/3] bg-neutral-08">
        <div className="flex h-full items-center justify-center text-neutral-05">
          <Gavel className="size-10" />
        </div>
        {badge && badgeLabels[badge] && (
          <Badge className={cn("absolute top-2 right-2", badgeLabels[badge].className)}>
            {badgeLabels[badge].label}
          </Badge>
        )}
      </div>
      <CardContent className="space-y-3 p-4">
        <Link href={itemUrl} className="block">
          <h3 className="line-clamp-1 text-sm font-medium text-neutral-01">
            {item.title}
          </h3>
        </Link>
        <p className="text-lg font-medium text-neutral-01">
          {formatNaira(price)}
        </p>
        <div className="flex items-center justify-between">
          <span className="inline-flex items-center gap-1 text-xs text-neutral-04">
            <Eye className="size-3" />
            {item.viewCount}
          </span>
          {item.endTime && <CountdownTimer endTime={item.endTime} />}
        </div>
        <div className="flex gap-2">
          <Button variant="outline" size="sm" className="flex-1">
            Watch
          </Button>
          <Button
            size="sm"
            className="flex-1 bg-primary-600 text-white hover:bg-primary-600/90"
            asChild
          >
            <Link href={itemUrl}>Bid</Link>
          </Button>
        </div>
      </CardContent>
    </Card>
  );
}
