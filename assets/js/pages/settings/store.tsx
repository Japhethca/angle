import { Head } from "@inertiajs/react";
import { SettingsLayout, StoreForm } from "@/features/settings";
import type { SettingsUser, StoreProfileData } from "@/features/settings";

interface SettingsStoreProps {
  user: SettingsUser;
  store_profile: StoreProfileData | null;
}

export default function SettingsStore({ user, store_profile }: SettingsStoreProps) {
  return (
    <>
      <Head title="Store Settings" />
      <SettingsLayout title="Store" breadcrumbSuffix="Store Profile">
        <StoreForm userId={user.id} storeProfile={store_profile} />
      </SettingsLayout>
    </>
  );
}
