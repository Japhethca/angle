import { useCallback, useRef, useState } from "react";
import { Camera, Trash2, User } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { getPhoenixCSRFToken } from "@/ash_rpc";
import { imageUrl, type ImageData } from "@/lib/image-url";

const ACCEPTED_TYPES = ["image/jpeg", "image/png", "image/webp"];
const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB

interface ProfileImageSectionProps {
  userId: string;
  avatarImages: ImageData[];
}

export function ProfileImageSection({
  userId,
  avatarImages: initialImages,
}: ProfileImageSectionProps) {
  const [images, setImages] = useState<ImageData[]>(initialImages);
  const [isUploading, setIsUploading] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const currentAvatar = images.length > 0 ? images[0] : null;

  const openFilePicker = useCallback(() => {
    fileInputRef.current?.click();
  }, []);

  const handleFileChange = useCallback(
    async (e: React.ChangeEvent<HTMLInputElement>) => {
      const file = e.target.files?.[0];
      e.target.value = "";
      if (!file) return;

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
        formData.append("owner_type", "user_avatar");
        formData.append("owner_id", userId);

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
    [userId]
  );

  const handleDelete = useCallback(async () => {
    if (!currentAvatar) return;

    const csrfToken = getPhoenixCSRFToken();
    try {
      const res = await fetch(`/uploads/${currentAvatar.id}`, {
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
  }, [currentAvatar]);

  return (
    <div className="flex items-center gap-4">
      {/* Avatar with camera badge */}
      <div className="relative shrink-0">
        <div className="flex size-16 items-center justify-center overflow-hidden rounded-full bg-surface-emphasis lg:size-20">
          {currentAvatar ? (
            <img
              src={imageUrl(currentAvatar, "medium")}
              alt="Profile avatar"
              className="size-full object-cover"
            />
          ) : (
            <User className="size-8 text-content-tertiary lg:size-10" />
          )}
        </div>
        {/* Camera badge overlay – mobile only */}
        <button
          type="button"
          onClick={openFilePicker}
          className="absolute -bottom-0.5 -right-0.5 flex size-6 items-center justify-center rounded-full border border-border bg-white lg:hidden"
        >
          <Camera className="size-3 text-content-secondary" />
        </button>
      </div>

      {/* Label and actions */}
      <div>
        <p className="mb-2 text-sm font-semibold text-content">Profile Image</p>
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
          {currentAvatar && (
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
      </div>

      {/* Hidden file input */}
      <input
        ref={fileInputRef}
        type="file"
        accept={ACCEPTED_TYPES.join(",")}
        onChange={handleFileChange}
        className="hidden"
      />
    </div>
  );
}
