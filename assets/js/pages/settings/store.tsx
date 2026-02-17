import { Head } from "@inertiajs/react";
import { SettingsLayout, StoreForm } from "@/features/settings";
import type { SettingsUser, StoreProfileData } from "@/features/settings";
import type { ImageData } from "@/lib/image-url";

interface SettingsStoreProps {
  user: SettingsUser;
  store_profile: StoreProfileData | null;
  logo_images: ImageData[];
}

export default function SettingsStore({ user, store_profile, logo_images }: SettingsStoreProps) {
  return (
    <>
      <Head title="Store Settings" />
      <SettingsLayout title="Store">
        <StoreForm userId={user.id} storeProfile={store_profile} logoImages={logo_images} />
      </SettingsLayout>
    </>
  );
}
