import { Head } from "@inertiajs/react";
import { ListingWizard, type Category } from "@/features/listing-form/components/listing-wizard";

interface NewItemPageProps {
  categories: Category[];
  storeProfile: { deliveryPreference: string | null } | null;
}

export default function NewItem({ categories, storeProfile }: NewItemPageProps) {
  return (
    <>
      <Head title="List An Item" />
      <div className="mx-auto max-w-2xl px-4 py-6 lg:max-w-3xl">
        <ListingWizard categories={categories} storeProfile={storeProfile} />
      </div>
    </>
  );
}
