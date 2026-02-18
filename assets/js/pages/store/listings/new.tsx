import { Head } from "@inertiajs/react";
import { ListingWizard, type Category } from "@/features/listing-form/components/listing-wizard";
import { StoreLayout } from "@/features/store-dashboard";

interface NewItemPageProps {
  categories: Category[];
  store_profile: { deliveryPreference: string | null } | null;
}

export default function NewItem({ categories, store_profile }: NewItemPageProps) {
  return (
    <>
      <Head title="List An Item" />
      <StoreLayout title="List An Item">
        <ListingWizard categories={categories} storeProfile={store_profile} />
      </StoreLayout>
    </>
  );
}
