import { useState } from "react";
import { Gavel, Play } from "lucide-react";
import { cn } from "@/lib/utils";

interface ItemImageGalleryProps {
  title: string;
}

const THUMBNAIL_COUNT = 5;

export function ItemImageGallery({ title }: ItemImageGalleryProps) {
  const [activeIndex, setActiveIndex] = useState(0);

  return (
    <>
      {/* Desktop: side-by-side thumbnails + main image */}
      <div className="hidden gap-3 lg:flex">
        {/* Thumbnail strip */}
        <div className="flex w-[72px] shrink-0 flex-col gap-2">
          {Array.from({ length: THUMBNAIL_COUNT }).map((_, i) => (
            <button
              key={i}
              onClick={() => setActiveIndex(i)}
              className={cn(
                "relative flex aspect-square items-center justify-center rounded-lg bg-surface-muted transition-all",
                activeIndex === i
                  ? "ring-2 ring-primary-600"
                  : "opacity-70 hover:opacity-100"
              )}
            >
              <Gavel className="size-5 text-content-placeholder" />
              {/* Video placeholder on last thumbnail */}
              {i === THUMBNAIL_COUNT - 1 && (
                <div className="absolute inset-0 flex items-center justify-center rounded-lg bg-black/30">
                  <Play className="size-4 fill-white text-white" />
                </div>
              )}
            </button>
          ))}
        </div>

        {/* Main image */}
        <div className="flex flex-1 items-center justify-center rounded-2xl bg-surface-muted">
          <div className="flex aspect-square w-full items-center justify-center">
            <Gavel className="size-24 text-content-placeholder" />
          </div>
        </div>
      </div>

      {/* Mobile: single image */}
      <div className="lg:hidden">
        <div className="flex aspect-[4/3] items-center justify-center rounded-2xl bg-surface-muted">
          <Gavel className="size-16 text-content-placeholder" />
        </div>
      </div>
    </>
  );
}
