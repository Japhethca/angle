import { Head } from "@inertiajs/react";
import { SettingsLayout, AccountForm } from "@/features/settings";
import type { SettingsUser } from "@/features/settings";
import type { ImageData } from "@/lib/image-url";

interface SettingsAccountProps {
  user: SettingsUser;
  avatar_images: ImageData[];
}

export default function SettingsAccount({
  user,
  avatar_images,
}: SettingsAccountProps) {
  return (
    <>
      <Head title="Account Settings" />
      <SettingsLayout title="Account">
        <AccountForm user={user} avatarImages={avatar_images} />
      </SettingsLayout>
    </>
  );
}
