import { useState } from "react";
import { router } from "@inertiajs/react";
import { MoreVertical, Share2, Pencil, Trash2, BarChart3 } from "lucide-react";
import { toast } from "sonner";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";

interface ListingActionsMenuProps {
  id: string;
  slug: string;
  publicationStatus: string | null | undefined;
}

export function ListingActionsMenu({ id, slug, publicationStatus }: ListingActionsMenuProps) {
  const [showDeleteDialog, setShowDeleteDialog] = useState(false);
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

  const handleAnalytics = () => {
    router.visit(`/store/listings/${id}/analytics`);
  };

  const handleDelete = () => {
    if (isDeleting) return;

    setIsDeleting(true);
    router.delete(`/store/listings/${id}`, {
      preserveScroll: true,
      onSuccess: () => setShowDeleteDialog(false),
      onError: () => {
        toast.error("Failed to delete listing");
        setShowDeleteDialog(false);
      },
      onFinish: () => setIsDeleting(false),
    });
  };

  return (
    <>
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <button className="flex size-8 items-center justify-center rounded-lg text-content-tertiary transition-colors hover:bg-surface-secondary hover:text-content">
            <MoreVertical className="size-4" />
          </button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          {!isDraft && (
            <DropdownMenuItem onClick={handleAnalytics}>
              <BarChart3 />
              Analytics
            </DropdownMenuItem>
          )}
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
            onSelect={() => setShowDeleteDialog(true)}
            className="text-feedback-error"
          >
            <Trash2 />
            Delete
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>

      <AlertDialog open={showDeleteDialog} onOpenChange={setShowDeleteDialog}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Delete listing</AlertDialogTitle>
            <AlertDialogDescription>
              This action cannot be undone. This will permanently delete the listing.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancel</AlertDialogCancel>
            <AlertDialogAction
              onClick={(e) => {
                e.preventDefault();
                handleDelete();
              }}
              disabled={isDeleting}
              className="bg-feedback-error text-white hover:bg-feedback-error/90"
            >
              {isDeleting ? "Deleting..." : "Delete"}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  );
}
