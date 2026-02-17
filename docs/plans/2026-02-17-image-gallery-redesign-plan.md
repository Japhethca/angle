# Image Gallery Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the thumbnail-strip gallery with a grid mosaic layout and full-screen lightbox on the item detail page.

**Architecture:** Rewrite `ItemImageGallery` to render a CSS Grid mosaic on desktop (1 large + up to 4 small images in a 3-column, 2-row grid). Add an `ImageLightbox` component using shadcn Dialog for full-screen image viewing with keyboard navigation. Mobile keeps full-width single image but adds tap-to-open-lightbox.

**Tech Stack:** React 19, Tailwind CSS (grid), shadcn Dialog (Radix), Lucide icons

---

### Task 1: Build the ImageLightbox component

**Files:**
- Create: `assets/js/features/items/components/image-lightbox.tsx`
- Modify: `assets/js/features/items/index.ts` (add export)

**Context:** The lightbox is a full-screen modal that opens when any gallery image is clicked. It uses the existing shadcn Dialog component (Radix-based, already has portal support). The `ResponsiveImage` component from `@/components/image-upload` can be used for the main display image. The `imageUrl` function from `@/lib/image-url` generates URLs for variants: `"thumbnail"`, `"medium"`, `"full"`.

**Step 1: Create the ImageLightbox component**

```tsx
// assets/js/features/items/components/image-lightbox.tsx
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
      if (e.key === "ArrowRight") goNext();
      if (e.key === "ArrowLeft") goPrev();
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [open, goNext, goPrev]);

  if (images.length === 0) return null;
  const activeImage = images[activeIndex];

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent
        className="flex h-screen max-h-screen w-screen max-w-none flex-col gap-0 rounded-none border-none bg-black/95 p-0"
        showCloseButton={false}
        overlayClassName="bg-black/90"
      >
        {/* Header: close + counter */}
        <div className="flex items-center justify-between px-4 py-3">
          <button
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
```

**Step 2: Export from features/items barrel**

Add to `assets/js/features/items/index.ts`:

```ts
export { ImageLightbox } from './components/image-lightbox';
```

Check the existing exports first — may need to add among existing exports.

**Step 3: Build and verify no compile errors**

Run: `mix assets.build` (from worktree root)
Expected: Clean build, no errors

**Step 4: Commit**

```bash
git add assets/js/features/items/components/image-lightbox.tsx assets/js/features/items/index.ts
git commit -m "feat: add ImageLightbox component"
```

---

### Task 2: Rewrite ItemImageGallery desktop grid

**Files:**
- Modify: `assets/js/features/items/components/item-image-gallery.tsx`

**Context:** Replace the current thumbnail-strip layout with a CSS Grid mosaic. The grid uses 3 columns (`[3fr_1fr_1fr]`) and 2 rows. The main image spans column 1 across both rows. Four smaller images fill the 2x2 grid on the right. The overall grid container has `aspect-[2/1]` to control proportions. All images use `object-cover`. Clicking any image opens the lightbox.

The component must handle different image counts:
- **0 images**: Centered placeholder (Gavel icon) at `max-w-[640px]` with 4:3 aspect
- **1 image**: Centered single image at `max-w-[640px]` with 4:3 aspect, clickable to open lightbox
- **2 images**: `grid-cols-2`, two images side by side
- **3 images**: `grid-cols-[2fr_1fr]` + `grid-rows-2`, main left row-span-2, two stacked right
- **4 images**: `grid-cols-[3fr_1fr_1fr]` + `grid-rows-2`, main left, two top-right, one bottom-right spanning 2 cols
- **5+ images**: Full `grid-cols-[3fr_1fr_1fr]` + `grid-rows-2` grid. If >5, last cell shows "+N more" overlay

**Step 1: Rewrite the component**

First, discard uncommitted changes: `git checkout -- assets/js/features/items/components/item-image-gallery.tsx`

Then rewrite the file:

```tsx
// assets/js/features/items/components/item-image-gallery.tsx
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

  const openLightbox = (index: number) => {
    setLightboxIndex(index);
    setLightboxOpen(true);
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
          onClick={() => openLightbox(0)}
          className="w-full"
        >
          <div className="aspect-[4/3] overflow-hidden rounded-2xl bg-surface-muted">
            <ResponsiveImage
              image={images[0]}
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
                key={img.id}
                onClick={() => openLightbox(idx)}
                className={cn(
                  "size-2 rounded-full transition-colors",
                  idx === 0 ? "bg-primary-600" : "bg-surface-emphasis"
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
        onOpenChange={setLightboxOpen}
      />
    </>
  );
}
```

**Step 2: Build and verify**

Run: `mix assets.build`
Expected: Clean build, no errors

**Step 3: Visual verification**

1. Navigate to `localhost:<port>/items/samsung-s24-ultra-test` (no images — should show centered placeholder)
2. Insert test images for an item and check the grid renders correctly
3. Click an image to verify lightbox opens
4. Test keyboard navigation in lightbox (←, →, Escape)

**Step 4: Commit**

```bash
git add assets/js/features/items/components/item-image-gallery.tsx
git commit -m "feat: rewrite image gallery with grid mosaic and lightbox"
```

---

### Task 3: Verify show.tsx layout compatibility

**Files:**
- Possibly modify: `assets/js/pages/items/show.tsx`

**Context:** The item detail page uses a flex layout: left column (`flex-1`) and right column (`w-[400px]`). The new grid gallery fills the full left column width (no `max-w-[640px]` constraint for multi-image grids). Verify the grid looks right within this layout.

**Step 1: Check current show.tsx layout**

Read `assets/js/pages/items/show.tsx` and confirm:
- Left column is `<div className="min-w-0 flex-1 space-y-8">`
- `<ItemImageGallery title={item.title} images={itemImages} />` is rendered as first child
- No width constraints on the gallery's parent that would interfere

**Step 2: Visual verification at different widths**

Test at 1440px, 1280px, and 1024px viewport widths. The grid should fill the left column naturally at all sizes. If the grid feels too wide at 1440px+, add a `max-w-[800px]` constraint — but only if needed after visual check.

**Step 3: Commit if changes needed**

```bash
git add assets/js/pages/items/show.tsx
git commit -m "fix: adjust show page layout for grid gallery"
```

---

### Task 4: Run tests and final verification

**Files:** None (verification only)

**Step 1: Run the full test suite**

Run: `mix test` (from worktree root)
Expected: All tests pass (gallery is frontend-only, no backend changes)

**Step 2: Browser verification checklist**

Desktop (1440px):
- [ ] Item with 0 images: centered placeholder with Gavel icon
- [ ] Item with 1 image: centered single image, click opens lightbox
- [ ] Item with 5+ images: full grid mosaic, "+N more" on last cell
- [ ] Lightbox: arrows, keyboard nav, thumbnail strip, counter, close

Mobile (375px):
- [ ] Full-width image with dot indicators
- [ ] Tap opens lightbox

**Step 3: Final commit if any fixes needed**
