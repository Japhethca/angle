import { useState } from "react";
import {
  addToWatchlist,
  removeFromWatchlist,
  buildCSRFHeaders,
} from "@/ash_rpc";

interface UseWatchlistToggleOptions {
  itemId: string;
  watchlistEntryId: string | null;
  onAdd?: () => void;
  onRemove?: () => void;
}

export function useWatchlistToggle({
  itemId,
  watchlistEntryId,
  onAdd,
  onRemove,
}: UseWatchlistToggleOptions) {
  const [isWatchlisted, setIsWatchlisted] = useState(!!watchlistEntryId);
  const [entryId, setEntryId] = useState(watchlistEntryId);
  const [isPending, setIsPending] = useState(false);

  async function toggle() {
    if (isPending) return;
    setIsPending(true);

    if (isWatchlisted && entryId) {
      setIsWatchlisted(false);
      try {
        await removeFromWatchlist({
          identity: entryId,
          headers: buildCSRFHeaders(),
        });
        setEntryId(null);
        onRemove?.();
      } catch {
        setIsWatchlisted(true);
      }
    } else {
      setIsWatchlisted(true);
      try {
        const result = await addToWatchlist({
          input: { itemId },
          fields: ["id"],
          headers: buildCSRFHeaders(),
        });
        if (result.success) {
          setEntryId(result.data.id);
          onAdd?.();
        }
      } catch {
        setIsWatchlisted(false);
      }
    }

    setIsPending(false);
  }

  return { isWatchlisted, isPending, toggle };
}
