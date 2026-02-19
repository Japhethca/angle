import { useState } from "react";
import { router } from "@inertiajs/react";
import { MoreVertical, Share2, Pencil, Trash2 } from "lucide-react";
import { toast } from "sonner";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";

interface ListingActionsMenuProps {
  id: string;
  slug: string;
  publicationStatus: string | null | undefined;
}

export function ListingActionsMenu({ id, slug, publicationStatus }: ListingActionsMenuProps) {
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);

  const isDraft = publicationStatus === "draft";

  const handleShare = async () => {
    const url = `${window.location.origin}/items/${slug}`;
    try {
      await navigator.clipboard.writeText(url);
      toast.success("Item link copied to clipboard");
    } catch {
      toast.error("Failed to copy link");
    }
  };

  const handleEdit = () => {
    router.visit(`/store/listings/${id}/edit`);
  };

  const handleDelete = () => {
    if (!confirmDelete) {
      setConfirmDelete(true);
      return;
    }
    if (isDeleting) return;

    setIsDeleting(true);
    setConfirmDelete(false);
    router.delete(`/store/listings/${id}`, {
      preserveScroll: true,
      onFinish: () => setIsDeleting(false),
    });
  };

  return (
    <DropdownMenu onOpenChange={(open) => { if (!open) setConfirmDelete(false); }}>
      <DropdownMenuTrigger asChild>
        <button className="flex size-8 items-center justify-center rounded-lg text-content-tertiary transition-colors hover:bg-surface-secondary hover:text-content">
          <MoreVertical className="size-4" />
        </button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        <DropdownMenuItem onClick={handleShare}>
          <Share2 />
          Share
        </DropdownMenuItem>
        {isDraft && (
          <DropdownMenuItem onClick={handleEdit}>
            <Pencil />
            Edit
          </DropdownMenuItem>
        )}
        <DropdownMenuItem
          onClick={handleDelete}
          disabled={isDeleting}
          className={confirmDelete ? "text-feedback-error bg-feedback-error/10" : "text-feedback-error"}
        >
          <Trash2 />
          {confirmDelete ? "Confirm Delete" : "Delete"}
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
