import { useCallback, useRef, useState } from "react";
import { GripVertical, ImageIcon } from "lucide-react";
import { toast } from "sonner";
import { cn } from "@/lib/utils";
import { getPhoenixCSRFToken } from "@/ash_rpc";
import { imageUrl, type ImageData } from "@/lib/image-url";
import { Badge } from "@/components/ui/badge";
import { ImageUploader } from "./image-uploader";
import { UploadPreview } from "./upload-preview";

interface ItemImageManagerProps {
  itemId: string;
  images: ImageData[];
  onImagesChange: (images: ImageData[]) => void;
}

export function ItemImageManager({
  itemId,
  images,
  onImagesChange,
}: ItemImageManagerProps) {
  const [dragIndex, setDragIndex] = useState<number | null>(null);
  const [overIndex, setOverIndex] = useState<number | null>(null);
  const [isReordering, setIsReordering] = useState(false);

  // Keep a ref for optimistic revert on reorder failure
  const previousImagesRef = useRef<ImageData[]>(images);

  const sortedImages = [...images].sort((a, b) => a.position - b.position);

  // --- Reorder logic ---

  const handleReorder = useCallback(
    async (fromIndex: number, toIndex: number) => {
      if (fromIndex === toIndex) return;

      // Sort inside the callback to avoid closing over stale sortedImages
      const sorted = [...images].sort((a, b) => a.position - b.position);
      const reordered = [...sorted];
      const [moved] = reordered.splice(fromIndex, 1);
      reordered.splice(toIndex, 0, moved);

      // Re-index positions
      const withPositions = reordered.map((img, idx) => ({
        ...img,
        position: idx,
      }));

      // Save previous state for revert
      previousImagesRef.current = images;

      // Optimistic update
      onImagesChange(withPositions);
      setIsReordering(true);

      try {
        const csrfToken = getPhoenixCSRFToken();
        const res = await fetch("/uploads/reorder", {
          method: "PATCH",
          headers: {
            "Content-Type": "application/json",
            ...(csrfToken ? { "X-CSRF-Token": csrfToken } : {}),
          },
          body: JSON.stringify({
            item_id: itemId,
            image_ids: withPositions.map((img) => img.id),
          }),
        });

        if (!res.ok) {
          const body = await res
            .json()
            .catch(() => ({ error: "Reorder failed" }));
          throw new Error(body.error || "Reorder failed");
        }
      } catch (err) {
        // Revert on failure
        onImagesChange(previousImagesRef.current);
        toast.error(
          err instanceof Error ? err.message : "Failed to reorder images"
        );
      } finally {
        setIsReordering(false);
      }
    },
    [images, itemId, onImagesChange]
  );

  const handleDragStart = useCallback(
    (e: React.DragEvent, index: number) => {
      setDragIndex(index);
      e.dataTransfer.effectAllowed = "move";
      // Tag the drag data so the ImageUploader drop zone can ignore reorder drags
      e.dataTransfer.setData("text/x-reorder", String(index));
    },
    []
  );

  const handleDragOver = useCallback(
    (e: React.DragEvent, index: number) => {
      e.preventDefault();
      e.dataTransfer.dropEffect = "move";
      setOverIndex(index);
    },
    []
  );

  const handleDragLeave = useCallback(() => {
    setOverIndex(null);
  }, []);

  const handleDrop = useCallback(
    (e: React.DragEvent, toIndex: number) => {
      e.preventDefault();
      e.stopPropagation();

      if (dragIndex !== null && dragIndex !== toIndex) {
        handleReorder(dragIndex, toIndex);
      }

      setDragIndex(null);
      setOverIndex(null);
    },
    [dragIndex, handleReorder]
  );

  const handleDragEnd = useCallback(() => {
    setDragIndex(null);
    setOverIndex(null);
  }, []);

  // --- Remove logic ---

  const handleRemoveImage = useCallback(
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
          const body = await res
            .json()
            .catch(() => ({ error: "Delete failed" }));
          throw new Error(body.error || "Delete failed");
        }

        // Remove from images and re-index positions
        const remaining = images
          .filter((img) => img.id !== imageId)
          .sort((a, b) => a.position - b.position)
          .map((img, idx) => ({ ...img, position: idx }));

        onImagesChange(remaining);
      } catch (err) {
        toast.error(
          err instanceof Error ? err.message : "Failed to remove image"
        );
      }
    },
    [images, onImagesChange]
  );

  // --- Upload merge ---
  // ImageUploader is passed an empty images array so it only shows the
  // drop zone (not a duplicate grid). When it uploads a new file, it calls
  // onImagesChange with the newly uploaded image(s). We merge those into
  // our managed images list.

  const handleUploaderChange = useCallback(
    (uploaderImages: ImageData[]) => {
      if (uploaderImages.length === 0) return;

      // uploaderImages contains only the newly uploaded images (since we
      // pass images={[]} to ImageUploader). Merge them with existing images.
      const existingIds = new Set(images.map((img) => img.id));
      const newImages = uploaderImages.filter(
        (img) => !existingIds.has(img.id)
      );

      if (newImages.length > 0) {
        // Assign positions after the current last position
        const maxPosition = images.length > 0
          ? Math.max(...images.map((img) => img.position))
          : -1;

        const withPositions = newImages.map((img, idx) => ({
          ...img,
          position: maxPosition + 1 + idx,
        }));

        onImagesChange([...images, ...withPositions]);
      }
    },
    [images, onImagesChange]
  );

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <ImageIcon className="size-4 text-content-secondary" />
          <h3 className="text-sm font-medium text-content">Item Images</h3>
        </div>
        {images.length > 0 && (
          <span className="text-sm text-content-secondary">
            {images.length}/10 images
          </span>
        )}
      </div>

      {/* Draggable image grid */}
      {sortedImages.length > 0 && (
        <div className="grid grid-cols-3 gap-2 sm:grid-cols-4 md:grid-cols-5">
          {sortedImages.map((image, index) => (
            <div
              key={image.id}
              draggable={!isReordering}
              onDragStart={(e) => handleDragStart(e, index)}
              onDragOver={(e) => handleDragOver(e, index)}
              onDragLeave={handleDragLeave}
              onDrop={(e) => handleDrop(e, index)}
              onDragEnd={handleDragEnd}
              className={cn(
                "group relative cursor-grab active:cursor-grabbing",
                dragIndex === index && "opacity-40",
                overIndex === index &&
                  dragIndex !== index &&
                  "ring-2 ring-primary-500 ring-offset-1 rounded-lg"
              )}
            >
              {/* Cover badge */}
              {index === 0 && (
                <Badge
                  variant="secondary"
                  className="absolute left-1 top-1 z-10 text-[10px] leading-tight"
                >
                  Cover
                </Badge>
              )}

              {/* Drag handle indicator */}
              <div className="absolute right-1 top-1 z-10 flex size-5 items-center justify-center rounded bg-black/50 text-white opacity-0 transition-opacity group-hover:opacity-100">
                <GripVertical className="size-3" />
              </div>

              <UploadPreview
                src={imageUrl(image, "thumbnail")}
                onRemove={() => handleRemoveImage(image.id)}
                className="aspect-square"
              />
            </div>
          ))}
        </div>
      )}

      {/* Upload drop zone -- pass empty images so ImageUploader only shows
          the drop zone and pending upload indicators, not a duplicate grid */}
      {images.length < 10 && (
        <ImageUploader
          ownerType="item"
          ownerId={itemId}
          images={[]}
          onImagesChange={handleUploaderChange}
          multiple
          maxImages={10 - images.length}
        />
      )}

      {sortedImages.length > 1 && (
        <p className="text-xs text-content-tertiary">
          Drag images to reorder. The first image will be used as the cover.
        </p>
      )}
    </div>
  );
}
