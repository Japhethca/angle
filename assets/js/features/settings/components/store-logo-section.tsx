import { useState } from "react";
import { Monitor } from "lucide-react";
import { ImageUploader } from "@/components/image-upload";
import { imageUrl, type ImageData } from "@/lib/image-url";

interface StoreLogoSectionProps {
  storeProfileId: string | null;
  logoImages: ImageData[];
}

export function StoreLogoSection({
  storeProfileId,
  logoImages: initialImages,
}: StoreLogoSectionProps) {
  const [images, setImages] = useState<ImageData[]>(initialImages);
  const currentLogo = images.length > 0 ? images[0] : null;

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-4">
        {/* Logo preview */}
        <div className="flex size-16 shrink-0 items-center justify-center overflow-hidden rounded-2xl bg-surface-muted lg:size-20">
          {currentLogo ? (
            <img
              src={imageUrl(currentLogo, "medium")}
              alt="Store logo"
              className="size-full object-cover"
            />
          ) : (
            <Monitor className="size-8 text-primary-600 lg:size-10" />
          )}
        </div>
        <div>
          <p className="mb-2 text-sm font-semibold text-content">Store logo</p>
          <p className="text-xs text-content-tertiary">
            {storeProfileId
              ? "JPEG, PNG, or WebP up to 10MB"
              : "Save your store profile first to upload a logo"}
          </p>
        </div>
      </div>

      {/* Upload control - only shown when store profile exists */}
      {storeProfileId && (
        <ImageUploader
          ownerType="store_logo"
          ownerId={storeProfileId}
          images={images}
          onImagesChange={setImages}
          multiple={false}
        />
      )}
    </div>
  );
}
