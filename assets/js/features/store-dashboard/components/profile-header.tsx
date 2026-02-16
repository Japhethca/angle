import { Link } from "@inertiajs/react";
import { Store, BadgeCheck, Pencil, Share2 } from "lucide-react";
import { toast } from "sonner";

interface ProfileHeaderProps {
  storeName: string;
  username: string | null;
}

export function ProfileHeader({ storeName, username }: ProfileHeaderProps) {
  const handleShare = async () => {
    const storeUrl = `${window.location.origin}/store/${username || ""}`;
    try {
      await navigator.clipboard.writeText(storeUrl);
      toast.success("Store link copied to clipboard");
    } catch {
      toast.error("Failed to copy link");
    }
  };

  return (
    <div className="rounded-xl border border-surface-muted bg-white p-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
        <div className="flex items-start gap-4">
          {/* Avatar */}
          <div className="flex size-16 shrink-0 items-center justify-center rounded-full bg-surface-muted">
            <Store className="size-8 text-content-placeholder" />
          </div>

          <div>
            {/* Name + badge */}
            <div className="flex items-center gap-2">
              <h2 className="text-xl font-semibold text-content">
                {storeName}
              </h2>
              <BadgeCheck className="size-5 text-primary-600" />
            </div>

            {/* Stats row (placeholder) */}
            <p className="mt-1 text-sm text-content-tertiary">
              5 &starf; &bull; 95% &bull; 0 Reviews &bull; 0 followers
            </p>
          </div>
        </div>

        {/* Action buttons */}
        <div className="flex items-center gap-3">
          <Link
            href="/settings/store"
            className="flex items-center gap-2 rounded-full border border-strong px-4 py-2 text-sm font-medium text-content-secondary transition-colors hover:bg-surface-secondary"
          >
            <Pencil className="size-4" />
            Edit
          </Link>
          <button
            onClick={handleShare}
            className="flex items-center gap-2 rounded-full border border-strong px-4 py-2 text-sm font-medium text-content-secondary transition-colors hover:bg-surface-secondary"
          >
            <Share2 className="size-4" />
            Share
          </button>
        </div>
      </div>
    </div>
  );
}
