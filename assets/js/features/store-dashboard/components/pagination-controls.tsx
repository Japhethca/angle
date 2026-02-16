import {
  ChevronFirst,
  ChevronLast,
  ChevronLeft,
  ChevronRight,
} from "lucide-react";

interface Pagination {
  page: number;
  per_page: number;
  total: number;
  total_pages: number;
}

interface PaginationControlsProps {
  pagination: Pagination;
  status: string;
  onNavigate: (params: Record<string, string | number>) => void;
}

export function PaginationControls({ pagination: p, status, onNavigate }: PaginationControlsProps) {
  const startItem = (p.page - 1) * p.per_page + 1;
  const endItem = Math.min(p.page * p.per_page, p.total);

  function goToPage(page: number) {
    onNavigate({ status, page, per_page: p.per_page });
  }

  return (
    <div className="flex flex-col items-center justify-between gap-3 border-t border-surface-muted px-4 py-3 sm:flex-row">
      <div className="flex items-center gap-4 text-sm text-content-tertiary">
        <span>
          Showing {p.total > 0 ? startItem : 0}-{endItem} of {p.total} items
        </span>
        <div className="flex items-center gap-2">
          <span>Rows per page</span>
          <select
            value={p.per_page}
            onChange={(e) =>
              onNavigate({ status, page: 1, per_page: Number(e.target.value) })
            }
            className="rounded border border-surface-muted bg-white px-2 py-1 text-sm text-content"
          >
            <option value={10}>10</option>
            <option value={25}>25</option>
            <option value={50}>50</option>
          </select>
        </div>
      </div>

      <div className="flex items-center gap-2">
        <span className="text-sm text-content-tertiary">
          Page {p.page} of {p.total_pages}
        </span>
        <div className="flex items-center gap-1">
          <button
            onClick={() => goToPage(1)}
            disabled={p.page === 1}
            className="flex size-8 items-center justify-center rounded text-content-tertiary transition-colors hover:bg-surface-secondary disabled:opacity-30"
          >
            <ChevronFirst className="size-4" />
          </button>
          <button
            onClick={() => goToPage(p.page - 1)}
            disabled={p.page === 1}
            className="flex size-8 items-center justify-center rounded text-content-tertiary transition-colors hover:bg-surface-secondary disabled:opacity-30"
          >
            <ChevronLeft className="size-4" />
          </button>
          <button
            onClick={() => goToPage(p.page + 1)}
            disabled={p.page === p.total_pages}
            className="flex size-8 items-center justify-center rounded text-content-tertiary transition-colors hover:bg-surface-secondary disabled:opacity-30"
          >
            <ChevronRight className="size-4" />
          </button>
          <button
            onClick={() => goToPage(p.total_pages)}
            disabled={p.page === p.total_pages}
            className="flex size-8 items-center justify-center rounded text-content-tertiary transition-colors hover:bg-surface-secondary disabled:opacity-30"
          >
            <ChevronLast className="size-4" />
          </button>
        </div>
      </div>
    </div>
  );
}
