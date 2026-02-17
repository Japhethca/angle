import { useState } from "react";
import { Gavel } from "lucide-react";
import { cn } from "@/lib/utils";
import type { ImageData } from "@/lib/image-url";
import { ResponsiveImage } from "@/components/image-upload";
import { ImageLightbox } from "./image-lightbox";

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

function GridImage({
  image,
  alt,
  onClick,
  className,
  children,
}: {
  image: ImageData;
  alt: string;
  onClick: () => void;
  className?: string;
  children?: React.ReactNode;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn("relative overflow-hidden", className)}
    >
      <ResponsiveImage
        image={image}
        sizes="(max-width: 1280px) 50vw, 600px"
        alt={alt}
        className="h-full w-full object-cover"
      />
      {children}
    </button>
  );
}

function MoreOverlay({ count }: { count: number }) {
  return (
    <div className="absolute inset-0 flex items-center justify-center bg-black/50">
      <span className="text-lg font-semibold text-white">+{count} more</span>
    </div>
  );
}

export function ItemImageGallery({ title, images = [] }: ItemImageGalleryProps) {
  const [lightboxOpen, setLightboxOpen] = useState(false);
  const [lightboxIndex, setLightboxIndex] = useState(0);
  const [mobileIndex, setMobileIndex] = useState(0);

  const openLightbox = (index: number) => {
    setLightboxIndex(index);
    setLightboxOpen(true);
  };

  const handleLightboxChange = (open: boolean) => {
    setLightboxOpen(open);
    if (!open) setMobileIndex(lightboxIndex);
  };

  const hasImages = images.length > 0;

  // --- No images: placeholder ---
  if (!hasImages) {
    return (
      <>
        <div className="hidden lg:block">
          <div className="mx-auto flex aspect-[4/3] max-w-[640px] items-center justify-center rounded-2xl bg-surface-muted">
            <Placeholder />
          </div>
        </div>
        <div className="lg:hidden">
          <div className="flex aspect-[4/3] items-center justify-center rounded-2xl bg-surface-muted">
            <Placeholder />
          </div>
        </div>
      </>
    );
  }

  // --- Desktop grid (varies by image count) ---
  const desktopGrid = () => {
    if (images.length === 1) {
      return (
        <div className="mx-auto max-w-[640px]">
          <button
            type="button"
            onClick={() => openLightbox(0)}
            className="w-full overflow-hidden rounded-2xl bg-surface-muted"
          >
            <div className="aspect-[4/3] w-full">
              <ResponsiveImage
                image={images[0]}
                sizes="(max-width: 1280px) 60vw, 640px"
                alt={title}
                loading="eager"
              />
            </div>
          </button>
        </div>
      );
    }

    if (images.length === 2) {
      return (
        <div className="grid aspect-[2/1] grid-cols-2 gap-2 overflow-hidden rounded-2xl">
          <GridImage image={images[0]} alt={title} onClick={() => openLightbox(0)} />
          <GridImage image={images[1]} alt={`${title} 2`} onClick={() => openLightbox(1)} />
        </div>
      );
    }

    if (images.length === 3) {
      return (
        <div className="grid aspect-[2/1] grid-cols-[2fr_1fr] grid-rows-2 gap-2 overflow-hidden rounded-2xl">
          <GridImage image={images[0]} alt={title} onClick={() => openLightbox(0)} className="row-span-2" />
          <GridImage image={images[1]} alt={`${title} 2`} onClick={() => openLightbox(1)} />
          <GridImage image={images[2]} alt={`${title} 3`} onClick={() => openLightbox(2)} />
        </div>
      );
    }

    if (images.length === 4) {
      return (
        <div className="grid aspect-[2/1] grid-cols-[3fr_1fr_1fr] grid-rows-2 gap-2 overflow-hidden rounded-2xl">
          <GridImage image={images[0]} alt={title} onClick={() => openLightbox(0)} className="row-span-2" />
          <GridImage image={images[1]} alt={`${title} 2`} onClick={() => openLightbox(1)} />
          <GridImage image={images[2]} alt={`${title} 3`} onClick={() => openLightbox(2)} />
          <GridImage image={images[3]} alt={`${title} 4`} onClick={() => openLightbox(3)} className="col-span-2" />
        </div>
      );
    }

    // 5+ images
    const remaining = images.length - 5;
    return (
      <div className="grid aspect-[2/1] grid-cols-[3fr_1fr_1fr] grid-rows-2 gap-2 overflow-hidden rounded-2xl">
        <GridImage image={images[0]} alt={title} onClick={() => openLightbox(0)} className="row-span-2" />
        <GridImage image={images[1]} alt={`${title} 2`} onClick={() => openLightbox(1)} />
        <GridImage image={images[2]} alt={`${title} 3`} onClick={() => openLightbox(2)} />
        <GridImage image={images[3]} alt={`${title} 4`} onClick={() => openLightbox(3)} />
        <GridImage image={images[4]} alt={`${title} 5`} onClick={() => openLightbox(4)}>
          {remaining > 0 && <MoreOverlay count={remaining} />}
        </GridImage>
      </div>
    );
  };

  return (
    <>
      {/* Desktop grid */}
      <div className="hidden lg:block">{desktopGrid()}</div>

      {/* Mobile: full-width single image with dots */}
      <div className="lg:hidden">
        <button
          type="button"
          onClick={() => openLightbox(mobileIndex)}
          className="w-full"
        >
          <div className="aspect-[4/3] overflow-hidden rounded-2xl bg-surface-muted">
            <ResponsiveImage
              image={images[mobileIndex]}
              sizes="100vw"
              alt={title}
              loading="eager"
            />
          </div>
        </button>

        {images.length > 1 && (
          <div className="mt-3 flex justify-center gap-1.5">
            {images.map((img, idx) => (
              <button
                type="button"
                key={img.id}
                onClick={() => openLightbox(idx)}
                className={cn(
                  "size-2 rounded-full transition-colors",
                  idx === mobileIndex ? "bg-primary-600" : "bg-surface-emphasis"
                )}
              />
            ))}
          </div>
        )}
      </div>

      {/* Lightbox */}
      <ImageLightbox
        images={images}
        initialIndex={lightboxIndex}
        open={lightboxOpen}
        onOpenChange={handleLightboxChange}
      />
    </>
  );
}
