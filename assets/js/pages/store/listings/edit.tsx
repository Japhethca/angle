import { Head } from "@inertiajs/react";
import type { ItemDetail } from "@/ash_rpc";
import type { ImageData } from "@/lib/image-url";
import { StoreLayout } from "@/features/store-dashboard";
import {
  ListingWizard,
  type Category,
} from "@/features/listing-form/components/listing-wizard";

interface EditPageProps {
  item: ItemDetail[number];
  images: ImageData[];
  categories: Category[];
  store_profile: { deliveryPreference: string | null } | null;
  step: number;
}

export default function EditPage({
  item,
  images,
  categories,
  store_profile,
  step,
}: EditPageProps) {
  const attrs = (item.attributes || {}) as Record<string, string>;
  const resolved = resolveCategory(categories, item.category?.id || "");

  const initialData = {
    draftItemId: item.id,
    basicDetails: {
      title: item.title || "",
      description: item.description || "",
      categoryId: resolved.categoryId,
      subcategoryId: resolved.subcategoryId,
      condition: (item.condition as "new" | "used" | "refurbished") || "used",
      attributes: Object.fromEntries(
        Object.entries(attrs).filter(([key]) => !key.startsWith("_")),
      ),
      customFeatures: attrs._customFeatures
        ? attrs._customFeatures.split("|||")
        : ["", "", ""],
    },
    auctionInfo: {
      startingPrice: item.startingPrice || "",
      reservePrice: item.reservePrice || "",
      auctionDuration:
        (attrs._auctionDuration as "24h" | "3d" | "7d") || "7d",
    },
    logistics: {
      deliveryPreference:
        (attrs._deliveryPreference as
          | "meetup"
          | "buyer_arranges"
          | "seller_arranges") || "buyer_arranges",
    },
    uploadedImages: images.map((img, i) => ({
      id: img.id,
      position: i,
      variants: img.variants || {},
    })),
    step: Math.min(Math.max(step, 1), 3) as 1 | 2 | 3,
  };

  return (
    <>
      <Head title="Edit Listing" />
      <StoreLayout title="Edit Listing">
        <ListingWizard
          categories={categories}
          storeProfile={store_profile}
          initialData={initialData}
        />
      </StoreLayout>
    </>
  );
}

/** Check if the stored category_id is a subcategory or top-level and set IDs accordingly. */
function resolveCategory(
  categories: Category[],
  storedId: string,
): { categoryId: string; subcategoryId: string } {
  if (!storedId) return { categoryId: "", subcategoryId: "" };

  for (const cat of categories) {
    if (cat.id === storedId) {
      return { categoryId: storedId, subcategoryId: "" };
    }
    for (const sub of cat.categories) {
      if (sub.id === storedId) {
        return { categoryId: storedId, subcategoryId: storedId };
      }
    }
  }

  // Fallback: treat as top-level
  return { categoryId: storedId, subcategoryId: "" };
}
