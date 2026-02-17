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
  storeProfile: { deliveryPreference: string | null } | null;
  step: number;
}

export default function EditPage({
  item,
  images,
  categories,
  storeProfile,
  step,
}: EditPageProps) {
  const attrs = (item.attributes || {}) as Record<string, string>;

  const initialData = {
    draftItemId: item.id,
    basicDetails: {
      title: item.title || "",
      description: item.description || "",
      categoryId: item.category?.id || "",
      subcategoryId: "",
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
          storeProfile={storeProfile}
          initialData={initialData}
        />
      </StoreLayout>
    </>
  );
}
