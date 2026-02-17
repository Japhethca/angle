import { cn } from "@/lib/utils";
import { imageUrl, VARIANT_WIDTHS, type ImageData } from "@/lib/image-url";

interface ResponsiveImageProps {
  image: ImageData;
  sizes: string;
  alt?: string;
  className?: string;
  loading?: "lazy" | "eager";
}

/**
 * Renders an <img> with srcSet for all 3 variants (200w, 600w, 1200w).
 * The browser picks the best variant based on rendered size and device pixel ratio.
 *
 * Usage:
 *   <ResponsiveImage image={coverImage} sizes="(max-width: 640px) 85vw, 432px" />
 */
export function ResponsiveImage({
  image,
  sizes,
  alt = "",
  className,
  loading = "lazy",
}: ResponsiveImageProps) {
  const srcSet = (["thumbnail", "medium", "full"] as const)
    .filter((v) => image.variants[v])
    .map((v) => `${imageUrl(image, v)} ${VARIANT_WIDTHS[v]}w`)
    .join(", ");

  return (
    <img
      src={imageUrl(image, "medium")}
      srcSet={srcSet}
      sizes={sizes}
      alt={alt}
      className={cn("h-full w-full object-cover", className)}
      loading={loading}
    />
  );
}
