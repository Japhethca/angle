# Listing Form & Detail Page Fixes

**Goal:** Fix image management bugs in the listing form, improve category field placement, and render item attributes on the detail page.

## Fix 1: Delete Uploaded Images

**Problem:** After saving a draft, previously uploaded images show as thumbnails but have no way to remove them. Only newly selected (unsaved) files can be removed.

**Solution:** Add an `x` button overlay on each uploaded image thumbnail. On click, call `DELETE /uploads/:id` to remove the image from the server, then update local state to remove it from the `existingImages` array. Include a loading/disabled state during deletion to prevent double-clicks.

## Fix 2: Multi-Image Upload Bug

**Problem:** When selecting multiple images via the file picker, the same image appears duplicated (e.g., selecting 3 files shows the same preview 3 times). Root cause: `e.target.value` is not reset after reading files, so subsequent selections re-read stale data.

**Solution:** Reset `e.target.value = ""` after processing the selected files in `handleImageSelect`. This ensures the browser treats each file selection as fresh input.

## Fix 3: Category Attribute Fields Placement

**Problem:** Category-specific attribute fields (e.g., Brand, Model, Storage) appear below the Features textarea, far from the category selector. They should be contextually grouped with the category.

**Solution:** Move the `<CategoryFields>` rendering block to appear directly below the Category/Condition grid row, before the Features section. This groups related fields together.

## Fix 4: Item Attributes on Detail Page

**Problem:** The Features tab on the item detail page shows placeholder text ("Feature details will be available soon") instead of actual item attributes.

**Solution:** Pass `attributes` from the item data to `ItemDetailTabs`. Render attributes as a two-column key-value grid for category attributes (structured data from `attribute_schema`), plus a checklist with check icons for custom features (from the features field). Use a clean layout with subtle borders and consistent spacing.
