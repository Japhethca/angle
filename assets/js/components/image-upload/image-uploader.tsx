import { useCallback, useRef, useState } from "react";
import { ImagePlus, Upload } from "lucide-react";
import { toast } from "sonner";
import { cn } from "@/lib/utils";
import { getPhoenixCSRFToken } from "@/ash_rpc";
import { imageUrl, type ImageData } from "@/lib/image-url";
import { UploadPreview } from "./upload-preview";

const ACCEPTED_TYPES = ["image/jpeg", "image/png", "image/webp"];
const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB

interface PendingUpload {
  id: string;
  previewUrl: string;
  progress?: number;
}

interface ImageUploaderProps {
  ownerType: "item" | "user_avatar" | "store_logo";
  ownerId: string;
  images: ImageData[];
  onImagesChange: (images: ImageData[]) => void;
  multiple?: boolean;
  maxImages?: number;
  className?: string;
}

export function ImageUploader({
  ownerType,
  ownerId,
  images,
  onImagesChange,
  multiple = false,
  maxImages = 10,
  className,
}: ImageUploaderProps) {
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [pending, setPending] = useState<PendingUpload[]>([]);
  const [isDragOver, setIsDragOver] = useState(false);

  // Keep a ref to the latest images and callback so concurrent uploads
  // don't close over stale values
  const imagesRef = useRef(images);
  imagesRef.current = images;
  const onImagesChangeRef = useRef(onImagesChange);
  onImagesChangeRef.current = onImagesChange;

  const totalCount = images.length + pending.length;
  const canAddMore = multiple ? totalCount < maxImages : images.length === 0 && pending.length === 0;

  const validateFile = useCallback((file: File): string | null => {
    if (!ACCEPTED_TYPES.includes(file.type)) {
      return `"${file.name}" is not a supported format. Use JPEG, PNG, or WebP.`;
    }
    if (file.size > MAX_FILE_SIZE) {
      return `"${file.name}" is too large. Maximum 10MB.`;
    }
    return null;
  }, []);

  const uploadFile = useCallback(
    async (file: File) => {
      const pendingId = crypto.randomUUID();
      const previewUrl = URL.createObjectURL(file);

      const pendingEntry: PendingUpload = {
        id: pendingId,
        previewUrl,
      };

      setPending((prev) => [...prev, pendingEntry]);

      try {
        const formData = new FormData();
        formData.append("file", file);
        formData.append("owner_type", ownerType);
        formData.append("owner_id", ownerId);

        const csrfToken = getPhoenixCSRFToken();

        const res = await fetch("/uploads", {
          method: "POST",
          headers: {
            ...(csrfToken ? { "X-CSRF-Token": csrfToken } : {}),
          },
          body: formData,
        });

        if (!res.ok) {
          const body = await res.json().catch(() => ({ error: "Upload failed" }));
          throw new Error(body.error || "Upload failed");
        }

        const newImage: ImageData = await res.json();

        // Remove from pending, add to images
        setPending((prev) => prev.filter((p) => p.id !== pendingId));
        URL.revokeObjectURL(previewUrl);

        // Read the latest images from ref to avoid stale closure issues
        // when multiple files are uploaded concurrently
        const currentImages = imagesRef.current;
        onImagesChangeRef.current(
          multiple
            ? [...currentImages, newImage].sort((a, b) => a.position - b.position)
            : [newImage]
        );
      } catch (err) {
        setPending((prev) => prev.filter((p) => p.id !== pendingId));
        URL.revokeObjectURL(previewUrl);
        toast.error(err instanceof Error ? err.message : "Upload failed");
      }
    },
    [ownerType, ownerId, multiple]
  );

  const handleFiles = useCallback(
    (fileList: FileList) => {
      const files = Array.from(fileList);

      // In single mode, only take the first file
      const filesToProcess = multiple ? files : files.slice(0, 1);

      // Check remaining capacity
      const remaining = multiple ? maxImages - totalCount : canAddMore ? 1 : 0;
      if (remaining <= 0) {
        toast.error(
          multiple
            ? `Maximum ${maxImages} images allowed`
            : "An image already exists. Remove it first."
        );
        return;
      }

      const accepted = filesToProcess.slice(0, remaining);

      for (const file of accepted) {
        const error = validateFile(file);
        if (error) {
          toast.error(error);
          continue;
        }
        uploadFile(file);
      }

      if (filesToProcess.length > remaining) {
        toast.error(
          `Only ${remaining} more image${remaining === 1 ? "" : "s"} can be added`
        );
      }
    },
    [multiple, maxImages, totalCount, canAddMore, validateFile, uploadFile]
  );

  const handleRemove = useCallback(
    async (imageId: string) => {
      const csrfToken = getPhoenixCSRFToken();

      try {
        const res = await fetch(`/uploads/${imageId}`, {
          method: "DELETE",
          headers: {
            ...(csrfToken ? { "X-CSRF-Token": csrfToken } : {}),
          },
        });

        if (!res.ok) {
          const body = await res.json().catch(() => ({ error: "Delete failed" }));
          throw new Error(body.error || "Delete failed");
        }

        onImagesChangeRef.current(
          imagesRef.current.filter((img) => img.id !== imageId)
        );
      } catch (err) {
        toast.error(err instanceof Error ? err.message : "Failed to remove image");
      }
    },
    []
  );

  const handleDragOver = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    setIsDragOver(true);
  }, []);

  const handleDragLeave = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    setIsDragOver(false);
  }, []);

  const handleDrop = useCallback(
    (e: React.DragEvent) => {
      e.preventDefault();
      setIsDragOver(false);
      if (e.dataTransfer.files.length > 0) {
        handleFiles(e.dataTransfer.files);
      }
    },
    [handleFiles]
  );

  const handleInputChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      if (e.target.files && e.target.files.length > 0) {
        handleFiles(e.target.files);
      }
      // Reset the input so re-selecting the same file triggers onChange
      e.target.value = "";
    },
    [handleFiles]
  );

  const openFilePicker = useCallback(() => {
    fileInputRef.current?.click();
  }, []);

  return (
    <div className={cn("space-y-3", className)}>
      {/* Header with count (multi mode only) */}
      {multiple && (
        <p className="text-sm text-content-secondary">
          {images.length}/{maxImages} images
        </p>
      )}

      {/* Image grid */}
      {(images.length > 0 || pending.length > 0) && (
        <div
          className={cn(
            "grid gap-2",
            multiple
              ? "grid-cols-3 sm:grid-cols-4 md:grid-cols-5"
              : "grid-cols-1 max-w-[200px]"
          )}
        >
          {/* Existing images */}
          {images.map((image) => (
            <UploadPreview
              key={image.id}
              src={imageUrl(image, "thumbnail")}
              onRemove={() => handleRemove(image.id)}
              className="aspect-square"
            />
          ))}

          {/* Pending uploads */}
          {pending.map((entry) => (
            <UploadPreview
              key={entry.id}
              src={entry.previewUrl}
              isUploading
              progress={entry.progress}
              className="aspect-square"
            />
          ))}
        </div>
      )}

      {/* Drop zone / add button */}
      {canAddMore && (
        <div
          role="button"
          tabIndex={0}
          onClick={openFilePicker}
          onKeyDown={(e) => {
            if (e.key === "Enter" || e.key === " ") {
              e.preventDefault();
              openFilePicker();
            }
          }}
          onDragOver={handleDragOver}
          onDragLeave={handleDragLeave}
          onDrop={handleDrop}
          className={cn(
            "flex cursor-pointer flex-col items-center justify-center gap-2 rounded-lg border-2 border-dashed p-6 transition-colors",
            isDragOver
              ? "border-primary-500 bg-primary-50"
              : "border-border hover:border-primary-400 hover:bg-surface-muted"
          )}
        >
          {images.length === 0 && pending.length === 0 ? (
            <>
              <ImagePlus className="size-8 text-content-tertiary" />
              <span className="text-sm text-content-secondary">
                {multiple
                  ? "Drag and drop images or click to browse"
                  : "Drag and drop an image or click to browse"}
              </span>
              <span className="text-xs text-content-tertiary">
                JPEG, PNG, or WebP up to 10MB
              </span>
            </>
          ) : (
            <>
              <Upload className="size-5 text-content-tertiary" />
              <span className="text-sm text-content-secondary">
                Add more images
              </span>
            </>
          )}
        </div>
      )}

      {/* Hidden file input */}
      <input
        ref={fileInputRef}
        type="file"
        accept={ACCEPTED_TYPES.join(",")}
        multiple={multiple}
        onChange={handleInputChange}
        className="hidden"
      />
    </div>
  );
}
