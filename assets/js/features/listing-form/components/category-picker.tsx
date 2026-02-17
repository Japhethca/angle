import { useState, useMemo } from "react";
import { ArrowLeft, ChevronRight, Check, Search } from "lucide-react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { cn } from "@/lib/utils";
import type { Category } from "./listing-wizard";

interface CategoryPickerProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  categories: Category[];
  selectedCategoryId: string;
  selectedSubcategoryId: string;
  onSelect: (categoryId: string, subcategoryId: string, categoryName: string) => void;
}

export function CategoryPicker({
  open,
  onOpenChange,
  categories,
  selectedCategoryId,
  selectedSubcategoryId,
  onSelect,
}: CategoryPickerProps) {
  const [activeParent, setActiveParent] = useState<Category | null>(null);
  const [searchQuery, setSearchQuery] = useState("");

  // Flat list of all subcategories for search
  const allSubcategories = useMemo(() => {
    return categories.flatMap((cat) =>
      cat.categories.map((sub) => ({
        ...sub,
        parentId: cat.id,
        parentName: cat.name,
      }))
    );
  }, [categories]);

  const filteredSubcategories = useMemo(() => {
    if (!searchQuery.trim()) return [];
    const q = searchQuery.toLowerCase();
    return allSubcategories.filter(
      (sub) =>
        sub.name.toLowerCase().includes(q) ||
        sub.parentName.toLowerCase().includes(q)
    );
  }, [allSubcategories, searchQuery]);

  const handleSelectSubcategory = (parentId: string, subId: string, name: string) => {
    onSelect(parentId, subId, name);
    onOpenChange(false);
    setActiveParent(null);
    setSearchQuery("");
  };

  const handleClose = () => {
    onOpenChange(false);
    setActiveParent(null);
    setSearchQuery("");
  };

  const isSearching = searchQuery.trim().length > 0;

  return (
    <Dialog open={open} onOpenChange={handleClose}>
      <DialogContent className="max-h-[80vh] overflow-hidden p-0 sm:max-w-md">
        <DialogHeader className="border-b px-4 py-3">
          <div className="flex items-center gap-2">
            {activeParent && !isSearching && (
              <button
                type="button"
                onClick={() => setActiveParent(null)}
                className="text-content-secondary hover:text-content"
              >
                <ArrowLeft className="size-5" />
              </button>
            )}
            <DialogTitle className="text-base">
              {activeParent && !isSearching ? activeParent.name : "Select Category"}
            </DialogTitle>
          </div>
        </DialogHeader>

        {/* Search */}
        <div className="border-b px-4 py-2">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-content-tertiary" />
            <Input
              placeholder="Search category"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="pl-9"
            />
          </div>
        </div>

        {/* Category list */}
        <div className="max-h-[50vh] overflow-y-auto">
          {isSearching ? (
            // Search results
            filteredSubcategories.length === 0 ? (
              <p className="p-4 text-center text-sm text-content-tertiary">
                No categories found
              </p>
            ) : (
              filteredSubcategories.map((sub) => (
                <button
                  key={sub.id}
                  type="button"
                  onClick={() => handleSelectSubcategory(sub.parentId, sub.id, sub.name)}
                  className="flex w-full items-center justify-between px-4 py-3 text-left text-sm hover:bg-surface-secondary"
                >
                  <div>
                    <span className="text-content">{sub.name}</span>
                    <span className="ml-2 text-xs text-content-tertiary">
                      in {sub.parentName}
                    </span>
                  </div>
                  {sub.id === selectedSubcategoryId && (
                    <Check className="size-4 text-primary-600" />
                  )}
                </button>
              ))
            )
          ) : activeParent ? (
            // Subcategories
            activeParent.categories.length === 0 ? (
              <p className="p-4 text-center text-sm text-content-tertiary">
                No subcategories
              </p>
            ) : (
              activeParent.categories.map((sub) => (
                <button
                  key={sub.id}
                  type="button"
                  onClick={() => handleSelectSubcategory(activeParent.id, sub.id, sub.name)}
                  className="flex w-full items-center justify-between px-4 py-3 text-left text-sm hover:bg-surface-secondary"
                >
                  <span className="text-content">{sub.name}</span>
                  {sub.id === selectedSubcategoryId && (
                    <Check className="size-4 text-primary-600" />
                  )}
                </button>
              ))
            )
          ) : (
            // Top-level categories
            categories.map((cat) => (
              <button
                key={cat.id}
                type="button"
                onClick={() => {
                  if (cat.categories.length > 0) {
                    setActiveParent(cat);
                  } else {
                    handleSelectSubcategory(cat.id, "", cat.name);
                  }
                }}
                className="flex w-full items-center justify-between px-4 py-3 text-left text-sm hover:bg-surface-secondary"
              >
                <span className="text-content">{cat.name}</span>
                {cat.categories.length > 0 ? (
                  <ChevronRight className="size-4 text-content-tertiary" />
                ) : cat.id === selectedCategoryId ? (
                  <Check className="size-4 text-primary-600" />
                ) : null}
              </button>
            ))
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
}
