import { X, Loader2 } from "lucide-react";
import { cn } from "@/lib/utils";

interface UploadPreviewProps {
  src: string;
  isUploading?: boolean;
  progress?: number;
  onRemove?: () => void;
  className?: string;
}

export function UploadPreview({
  src,
  isUploading,
  progress,
  onRemove,
  className,
}: UploadPreviewProps) {
  return (
    <div className={cn("group relative overflow-hidden rounded-lg", className)}>
      <img
        src={src}
        alt=""
        className={cn(
          "h-full w-full object-cover",
          isUploading && "opacity-50"
        )}
      />

      {isUploading && (
        <div className="absolute inset-0 flex items-center justify-center bg-black/30">
          <Loader2 className="size-6 animate-spin text-white" />
          {progress !== undefined && (
            <span className="absolute bottom-2 text-xs font-medium text-white">
              {Math.round(progress)}%
            </span>
          )}
        </div>
      )}

      {!isUploading && onRemove && (
        <button
          type="button"
          onClick={onRemove}
          className="absolute right-1 top-1 flex size-6 items-center justify-center rounded-full bg-black/60 text-white opacity-0 transition-opacity group-hover:opacity-100"
        >
          <X className="size-3.5" />
        </button>
      )}
    </div>
  );
}
