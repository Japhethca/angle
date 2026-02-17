import { useState } from "react";
import { Gavel } from "lucide-react";
import { cn } from "@/lib/utils";
import type { ImageData } from "@/lib/image-url";
import { ResponsiveImage } from "@/components/image-upload";
import { imageUrl } from "@/lib/image-url";

interface ItemImageGalleryProps {
  title: string;
  images?: ImageData[];
}

function Placeholder({ className }: { className?: string }) {
  return (
    <div className={cn("flex h-full items-center justify-center text-content-placeholder", className)}>
      <Gavel className="size-16 lg:size-24" />
    </div>
  );
}

export function ItemImageGallery({ title, images = [] }: ItemImageGalleryProps) {
  const [activeIndex, setActiveIndex] = useState(0);
  const hasImages = images.length > 0;
  const activeImage = hasImages ? images[activeIndex] : null;

  if (!hasImages) {
    return (
      <>
        {/* Desktop: placeholder */}
        <div className="hidden lg:block">
          <div className="flex aspect-square items-center justify-center rounded-2xl bg-surface-muted">
            <Placeholder />
          </div>
        </div>

        {/* Mobile: placeholder */}
        <div className="lg:hidden">
          <div className="flex aspect-[4/3] items-center justify-center rounded-2xl bg-surface-muted">
            <Placeholder />
          </div>
        </div>
      </>
    );
  }

  return (
    <>
      {/* Desktop: side-by-side thumbnails + main image */}
      <div className="hidden gap-2.5 lg:flex">
        {/* Thumbnail strip */}
        {images.length > 1 && (
          <div className="flex w-[72px] shrink-0 flex-col gap-2">
            {images.map((img, i) => (
              <button
                key={img.id}
                onClick={() => setActiveIndex(i)}
                className={cn(
                  "relative aspect-square overflow-hidden rounded-lg bg-surface-muted transition-all",
                  activeIndex === i
                    ? "ring-2 ring-primary-600"
                    : "opacity-70 hover:opacity-100"
                )}
              >
                <img
                  src={imageUrl(img, "thumbnail")}
                  alt={`${title} thumbnail ${i + 1}`}
                  className="h-full w-full object-cover"
                />
              </button>
            ))}
          </div>
        )}

        {/* Main image */}
        <div className="flex-1 overflow-hidden rounded-2xl bg-surface-muted">
          <div className="aspect-square w-full">
            {activeImage && (
              <ResponsiveImage
                image={activeImage}
                sizes="(max-width: 1280px) 60vw, 700px"
                alt={title}
                loading="eager"
              />
            )}
          </div>
        </div>
      </div>

      {/* Mobile: swipeable single image with dots */}
      <div className="lg:hidden">
        <div className="aspect-[4/3] overflow-hidden rounded-2xl bg-surface-muted">
          {activeImage && (
            <ResponsiveImage
              image={activeImage}
              sizes="100vw"
              alt={title}
              loading="eager"
            />
          )}
        </div>

        {/* Dot indicators for mobile */}
        {images.length > 1 && (
          <div className="mt-3 flex justify-center gap-1.5">
            {images.map((img, idx) => (
              <button
                key={img.id}
                onClick={() => setActiveIndex(idx)}
                className={cn(
                  "size-2 rounded-full transition-colors",
                  idx === activeIndex ? "bg-primary-600" : "bg-surface-emphasis"
                )}
              />
            ))}
          </div>
        )}
      </div>
    </>
  );
}
