export type ImageVariant = "thumbnail" | "medium" | "full";

/** Variant max widths -- must match server-side Processor config */
export const VARIANT_WIDTHS: Record<ImageVariant, number> = {
  thumbnail: 200,
  medium: 600,
  full: 1200,
};

export interface ImageData {
  id: string;
  variants: Record<string, string>;
  position: number;
  width: number;
  height: number;
}

/**
 * Returns the full URL for an image variant.
 * Variant URLs are stored as absolute URLs by the server.
 */
export function imageUrl(image: ImageData, variant: ImageVariant = "medium"): string {
  const url = image.variants[variant];
  if (!url) return "";
  return url;
}

/**
 * Returns the cover image (position 0) from an array of images,
 * or null if no images exist.
 */
export function coverImage(images: ImageData[]): ImageData | null {
  if (!images || images.length === 0) return null;
  return images.find((img) => img.position === 0) || images[0];
}
