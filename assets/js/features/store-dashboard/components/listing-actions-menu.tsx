import { useRef, useEffect, useState } from "react";
import { router } from "@inertiajs/react";
import { MoreVertical, Share2, Pencil, Trash2 } from "lucide-react";
import { toast } from "sonner";

interface ListingActionsMenuProps {
  id: string;
  slug: string;
  publicationStatus: string | null | undefined;
}

export function ListingActionsMenu({ id, slug, publicationStatus }: ListingActionsMenuProps) {
  const [open, setOpen] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (menuRef.current && !menuRef.current.contains(event.target as Node)) {
        setOpen(false);
        setConfirmDelete(false);
      }
    }

    if (open) {
      document.addEventListener("mousedown", handleClickOutside);
    }

    return () => {
      document.removeEventListener("mousedown", handleClickOutside);
    };
  }, [open]);

  const isDraft = publicationStatus === "draft";

  const handleShare = async () => {
    const url = `${window.location.origin}/items/${slug}`;
    try {
      await navigator.clipboard.writeText(url);
      toast.success("Item link copied to clipboard");
    } catch {
      toast.error("Failed to copy link");
    }
    setOpen(false);
  };

  const handleEdit = () => {
    setOpen(false);
    router.visit(`/store/listings/${id}/edit`);
  };

  const handleDelete = () => {
    if (!confirmDelete) {
      setConfirmDelete(true);
      return;
    }
    if (isDeleting) return;

    setIsDeleting(true);
    setOpen(false);
    setConfirmDelete(false);
    router.delete(`/store/listings/${id}`, {
      preserveScroll: true,
      onFinish: () => setIsDeleting(false),
    });
  };

  return (
    <div ref={menuRef} className="relative">
      <button
        onClick={() => {
          setOpen(!open);
          setConfirmDelete(false);
        }}
        className="flex size-8 items-center justify-center rounded-lg text-content-tertiary transition-colors hover:bg-surface-secondary hover:text-content"
      >
        <MoreVertical className="size-4" />
      </button>

      {open && (
        <div className="absolute right-0 top-full z-10 mt-1 w-40 rounded-lg border border-surface-muted bg-surface py-1 shadow-lg dark:shadow-black/20">
          <button
            onClick={handleShare}
            className="flex w-full items-center gap-2 px-3 py-2 text-sm text-content-secondary transition-colors hover:bg-surface-secondary"
          >
            <Share2 className="size-4" />
            Share
          </button>
          {isDraft && (
            <button
              onClick={handleEdit}
              className="flex w-full items-center gap-2 px-3 py-2 text-sm text-content-secondary transition-colors hover:bg-surface-secondary"
            >
              <Pencil className="size-4" />
              Edit
            </button>
          )}
          <button
            onClick={handleDelete}
            disabled={isDeleting}
            className={
              confirmDelete
                ? "flex w-full items-center gap-2 rounded px-3 py-2 text-sm font-medium text-feedback-error bg-feedback-error/10 transition-colors"
                : "flex w-full items-center gap-2 px-3 py-2 text-sm text-feedback-error transition-colors hover:bg-surface-secondary"
            }
          >
            <Trash2 className="size-4" />
            {confirmDelete ? "Confirm Delete" : "Delete"}
          </button>
        </div>
      )}
    </div>
  );
}
