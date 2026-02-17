import { useCallback, useRef, useState } from "react";
import { Camera, Monitor, Trash2 } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { getPhoenixCSRFToken } from "@/ash_rpc";
import { imageUrl, type ImageData } from "@/lib/image-url";

const ACCEPTED_TYPES = ["image/jpeg", "image/png", "image/webp"];
const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB

interface StoreLogoSectionProps {
  storeProfileId: string | null;
  logoImages: ImageData[];
}

export function StoreLogoSection({
  storeProfileId,
  logoImages: initialImages,
}: StoreLogoSectionProps) {
  const [images, setImages] = useState<ImageData[]>(initialImages);
  const [isUploading, setIsUploading] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const currentLogo = images.length > 0 ? images[0] : null;

  const openFilePicker = useCallback(() => {
    if (!storeProfileId) {
      toast.error("Save your store profile first to upload a logo");
      return;
    }
    fileInputRef.current?.click();
  }, [storeProfileId]);

  const handleFileChange = useCallback(
    async (e: React.ChangeEvent<HTMLInputElement>) => {
      const file = e.target.files?.[0];
      e.target.value = "";
      if (!file || !storeProfileId) return;

      if (!ACCEPTED_TYPES.includes(file.type)) {
        toast.error("Use JPEG, PNG, or WebP format.");
        return;
      }
      if (file.size > MAX_FILE_SIZE) {
        toast.error("Image must be under 10MB.");
        return;
      }

      setIsUploading(true);
      try {
        const formData = new FormData();
        formData.append("file", file);
        formData.append("owner_type", "store_logo");
        formData.append("owner_id", storeProfileId);

        const csrfToken = getPhoenixCSRFToken();
        const res = await fetch("/uploads", {
          method: "POST",
          headers: csrfToken ? { "X-CSRF-Token": csrfToken } : {},
          body: formData,
        });

        if (!res.ok) {
          const body = await res
            .json()
            .catch(() => ({ error: "Upload failed" }));
          throw new Error(body.error || "Upload failed");
        }

        const newImage: ImageData = await res.json();
        setImages([newImage]);
      } catch (err) {
        toast.error(err instanceof Error ? err.message : "Upload failed");
      } finally {
        setIsUploading(false);
      }
    },
    [storeProfileId]
  );

  const handleDelete = useCallback(async () => {
    if (!currentLogo) return;

    const csrfToken = getPhoenixCSRFToken();
    try {
      const res = await fetch(`/uploads/${currentLogo.id}`, {
        method: "DELETE",
        headers: csrfToken ? { "X-CSRF-Token": csrfToken } : {},
      });

      if (!res.ok) {
        const body = await res
          .json()
          .catch(() => ({ error: "Delete failed" }));
        throw new Error(body.error || "Delete failed");
      }

      setImages([]);
    } catch (err) {
      toast.error(
        err instanceof Error ? err.message : "Failed to remove image"
      );
    }
  }, [currentLogo]);

  return (
    <div className="flex items-center gap-4">
      {/* Logo with camera badge */}
      <div className="relative shrink-0">
        <div className="flex size-16 items-center justify-center overflow-hidden rounded-2xl bg-surface-muted lg:size-20">
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
        {/* Camera badge overlay – mobile only */}
        {storeProfileId && (
          <button
            type="button"
            onClick={openFilePicker}
            className="absolute -bottom-0.5 -right-0.5 flex size-6 items-center justify-center rounded-full border border-border bg-white lg:hidden"
          >
            <Camera className="size-3 text-content-secondary" />
          </button>
        )}
      </div>

      {/* Label and actions */}
      <div>
        <p className="mb-2 text-sm font-semibold text-content">Store logo</p>
        {storeProfileId ? (
          <div className="flex items-center gap-2">
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={openFilePicker}
              disabled={isUploading}
              className="rounded-full"
            >
              {isUploading ? "Uploading..." : "Change"}
              <Camera className="size-3.5" />
            </Button>
            {currentLogo && (
              <>
                {/* Desktop: text button */}
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  onClick={handleDelete}
                  className="hidden rounded-full lg:inline-flex"
                >
                  Delete
                </Button>
                {/* Mobile: icon-only delete */}
                <button
                  type="button"
                  onClick={handleDelete}
                  className="flex size-8 items-center justify-center text-content-tertiary hover:text-content lg:hidden"
                >
                  <Trash2 className="size-4" />
                </button>
              </>
            )}
          </div>
        ) : (
          <p className="text-xs text-content-tertiary">
            Save your store profile first to upload a logo
          </p>
        )}
      </div>

      {/* Hidden file input */}
      {storeProfileId && (
        <input
          ref={fileInputRef}
          type="file"
          accept={ACCEPTED_TYPES.join(",")}
          onChange={handleFileChange}
          className="hidden"
        />
      )}
    </div>
  );
}
