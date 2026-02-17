import { Head } from "@inertiajs/react";
import { ListingWizard, type Category } from "@/features/listing-form/components/listing-wizard";
import { StoreLayout } from "@/features/store-dashboard";

interface NewItemPageProps {
  categories: Category[];
  storeProfile: { deliveryPreference: string | null } | null;
}

export default function NewItem({ categories, storeProfile }: NewItemPageProps) {
  return (
    <>
      <Head title="List An Item" />
      <StoreLayout title="List An Item">
        <ListingWizard categories={categories} storeProfile={storeProfile} />
      </StoreLayout>
    </>
  );
}
