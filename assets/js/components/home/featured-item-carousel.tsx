import { useState } from "react";
import { Link } from "@inertiajs/react";
import { ChevronLeft, ChevronRight, Gavel } from "lucide-react";
import type { HomepageItemCard } from "@/ash_rpc";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { CountdownTimer } from "@/components/shared/countdown-timer";
import { formatNaira } from "@/lib/format";
import { cn } from "@/lib/utils";

type Item = HomepageItemCard[number];

interface FeaturedItemCarouselProps {
  items: Item[];
}

export function FeaturedItemCarousel({ items }: FeaturedItemCarouselProps) {
  const [currentIndex, setCurrentIndex] = useState(0);

  if (items.length === 0) {
    return (
      <section className="mx-auto max-w-7xl px-4 py-8 lg:px-8">
        <div className="flex aspect-[4/3] flex-col items-center justify-center rounded-xl bg-neutral-08 lg:aspect-[21/9]">
          <Gavel className="mb-3 size-12 text-neutral-05" />
          <p className="text-sm text-neutral-04">No featured items yet</p>
        </div>
      </section>
    );
  }

  const activeItem = items[currentIndex];
  const itemUrl = `/items/${activeItem.slug || activeItem.id}`;
  const price = activeItem.currentPrice || activeItem.startingPrice;

  const goPrev = () =>
    setCurrentIndex((i) => (i === 0 ? items.length - 1 : i - 1));
  const goNext = () =>
    setCurrentIndex((i) => (i === items.length - 1 ? 0 : i + 1));

  return (
    <section className="mx-auto max-w-7xl px-4 py-8 lg:px-8">
      <div className="grid gap-6 lg:grid-cols-12">
        {/* Main featured image */}
        <div className="relative aspect-[4/3] overflow-hidden rounded-xl bg-neutral-08 lg:col-span-8">
          <div className="flex h-full items-center justify-center text-neutral-05">
            <Gavel className="size-16" />
          </div>

          {/* Prev/Next overlay buttons */}
          <div className="absolute inset-y-0 left-0 flex items-center pl-3">
            <Button
              variant="secondary"
              size="icon"
              className="rounded-full bg-white/80 shadow-md"
              onClick={goPrev}
            >
              <ChevronLeft className="size-5" />
            </Button>
          </div>
          <div className="absolute inset-y-0 right-0 flex items-center pr-3">
            <Button
              variant="secondary"
              size="icon"
              className="rounded-full bg-white/80 shadow-md"
              onClick={goNext}
            >
              <ChevronRight className="size-5" />
            </Button>
          </div>
        </div>

        {/* Details + thumbnails */}
        <div className="flex flex-col gap-4 lg:col-span-4">
          <div className="space-y-3">
            <Link href={itemUrl}>
              <h2 className="font-heading text-xl font-semibold text-neutral-01">
                {activeItem.title}
              </h2>
            </Link>
            <p className="text-2xl font-medium text-neutral-01">
              {formatNaira(price)}
            </p>
            {activeItem.endTime && (
              <CountdownTimer endTime={activeItem.endTime} />
            )}
            <div className="flex gap-2 pt-2">
              <Button variant="outline" className="flex-1">
                Watch
              </Button>
              <Button
                className="flex-1 bg-primary-600 text-white hover:bg-primary-600/90"
                asChild
              >
                <Link href={itemUrl}>Place Bid</Link>
              </Button>
            </div>
          </div>

          {/* Thumbnail list */}
          <div className="flex gap-2 overflow-x-auto lg:flex-col">
            {items.map((item, idx) => (
              <Card
                key={item.id}
                className={cn(
                  "flex shrink-0 cursor-pointer items-center gap-3 p-2 transition-all",
                  idx === currentIndex
                    ? "ring-2 ring-primary-600"
                    : "hover:bg-neutral-08"
                )}
                onClick={() => setCurrentIndex(idx)}
              >
                <div className="flex size-12 shrink-0 items-center justify-center rounded bg-neutral-08">
                  <Gavel className="size-5 text-neutral-05" />
                </div>
                <div className="min-w-0">
                  <p className="truncate text-xs font-medium text-neutral-01">
                    {item.title}
                  </p>
                  <p className="text-xs text-neutral-04">
                    {formatNaira(item.currentPrice || item.startingPrice)}
                  </p>
                </div>
              </Card>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
