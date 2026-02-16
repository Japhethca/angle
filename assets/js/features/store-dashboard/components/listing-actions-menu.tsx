import { useRef, useEffect, useState } from "react";
import { MoreVertical, Share2, Pencil, Trash2 } from "lucide-react";
import { toast } from "sonner";

interface ListingActionsMenuProps {
  slug: string;
}

export function ListingActionsMenu({ slug }: ListingActionsMenuProps) {
  const [open, setOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (menuRef.current && !menuRef.current.contains(event.target as Node)) {
        setOpen(false);
      }
    }

    if (open) {
      document.addEventListener("mousedown", handleClickOutside);
    }

    return () => {
      document.removeEventListener("mousedown", handleClickOutside);
    };
  }, [open]);

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
    toast.info("Coming soon");
    setOpen(false);
  };

  const handleDelete = () => {
    toast.info("Coming soon");
    setOpen(false);
  };

  return (
    <div ref={menuRef} className="relative">
      <button
        onClick={() => setOpen(!open)}
        className="flex size-8 items-center justify-center rounded-lg text-content-tertiary transition-colors hover:bg-surface-secondary hover:text-content"
      >
        <MoreVertical className="size-4" />
      </button>

      {open && (
        <div className="absolute right-0 top-full z-10 mt-1 w-40 rounded-lg border border-surface-muted bg-white py-1 shadow-lg">
          <button
            onClick={handleShare}
            className="flex w-full items-center gap-2 px-3 py-2 text-sm text-content-secondary transition-colors hover:bg-surface-secondary"
          >
            <Share2 className="size-4" />
            Share
          </button>
          <button
            onClick={handleEdit}
            className="flex w-full items-center gap-2 px-3 py-2 text-sm text-content-secondary transition-colors hover:bg-surface-secondary"
          >
            <Pencil className="size-4" />
            Edit
          </button>
          <button
            onClick={handleDelete}
            className="flex w-full items-center gap-2 px-3 py-2 text-sm text-feedback-error transition-colors hover:bg-surface-secondary"
          >
            <Trash2 className="size-4" />
            Delete
          </button>
        </div>
      )}
    </div>
  );
}
