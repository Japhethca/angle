import { useCallback, useEffect, useState } from "react";
import { ChevronLeft, ChevronRight, X } from "lucide-react";
import { cn } from "@/lib/utils";
import { Dialog, DialogContent } from "@/components/ui/dialog";
import type { ImageData } from "@/lib/image-url";
import { imageUrl } from "@/lib/image-url";

interface ImageLightboxProps {
  images: ImageData[];
  initialIndex: number;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

export function ImageLightbox({
  images,
  initialIndex,
  open,
  onOpenChange,
}: ImageLightboxProps) {
  const [activeIndex, setActiveIndex] = useState(initialIndex);

  // Sync when lightbox opens at a new index
  useEffect(() => {
    if (open) setActiveIndex(initialIndex);
  }, [open, initialIndex]);

  const goNext = useCallback(() => {
    setActiveIndex((i) => (i + 1) % images.length);
  }, [images.length]);

  const goPrev = useCallback(() => {
    setActiveIndex((i) => (i - 1 + images.length) % images.length);
  }, [images.length]);

  // Keyboard navigation
  useEffect(() => {
    if (!open) return;
    const handler = (e: KeyboardEvent) => {
      if (e.key === "ArrowRight") {
        e.preventDefault();
        goNext();
      }
      if (e.key === "ArrowLeft") {
        e.preventDefault();
        goPrev();
      }
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [open, goNext, goPrev]);

  if (images.length === 0) return null;
  const activeImage = images[activeIndex];

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent
        className="flex h-screen max-h-screen w-screen max-w-none sm:max-w-none flex-col gap-0 rounded-none border-none bg-black/95 p-0 top-0 left-0 translate-x-0 translate-y-0"
        showCloseButton={false}
        overlayClassName="bg-black/90"
      >
        {/* Header: close + counter */}
        <div className="flex items-center justify-between px-4 py-3">
          <button
            type="button"
            onClick={() => onOpenChange(false)}
            className="flex size-9 items-center justify-center rounded-full text-white/70 hover:text-white"
          >
            <X className="size-5" />
          </button>
          <span className="text-sm text-white/70">
            {activeIndex + 1} / {images.length}
          </span>
        </div>

        {/* Main image area with nav arrows */}
        <div className="relative flex flex-1 items-center justify-center px-12">
          {/* Left arrow */}
          {images.length > 1 && (
            <button
              type="button"
              onClick={goPrev}
              className="absolute left-2 flex size-10 items-center justify-center rounded-full bg-white/10 text-white/70 hover:bg-white/20 hover:text-white"
            >
              <ChevronLeft className="size-6" />
            </button>
          )}

          {/* Image */}
          <img
            src={imageUrl(activeImage, "full")}
            alt={`Image ${activeIndex + 1}`}
            className="max-h-[calc(100vh-160px)] max-w-full object-contain"
          />

          {/* Right arrow */}
          {images.length > 1 && (
            <button
              type="button"
              onClick={goNext}
              className="absolute right-2 flex size-10 items-center justify-center rounded-full bg-white/10 text-white/70 hover:bg-white/20 hover:text-white"
            >
              <ChevronRight className="size-6" />
            </button>
          )}
        </div>

        {/* Thumbnail strip */}
        {images.length > 1 && (
          <div className="flex justify-center gap-2 overflow-x-auto px-4 py-3">
            {images.map((img, i) => (
              <button
                type="button"
                key={img.id}
                onClick={() => setActiveIndex(i)}
                className={cn(
                  "size-12 shrink-0 overflow-hidden rounded-lg transition-all",
                  activeIndex === i
                    ? "ring-2 ring-white"
                    : "opacity-50 hover:opacity-80"
                )}
              >
                <img
                  src={imageUrl(img, "thumbnail")}
                  alt={`Thumbnail ${i + 1}`}
                  className="h-full w-full object-cover"
                />
              </button>
            ))}
          </div>
        )}
      </DialogContent>
    </Dialog>
  );
}
