import { Head } from "@inertiajs/react";
import {
  SettingsLayout,
  AccountForm,
  PhoneVerification,
  IdUpload,
} from "@/features/settings";
import type { SettingsUser } from "@/features/settings";
import type { ImageData } from "@/lib/image-url";

interface UserVerification {
  id: string;
  phone_verified: boolean;
  phone_number: string | null;
  id_uploaded: boolean;
  id_verified: boolean;
  id_type: string | null;
}

interface SettingsAccountProps {
  user: SettingsUser;
  avatar_images: ImageData[];
  verification: UserVerification | null;
}

export default function SettingsAccount({
  user,
  avatar_images,
  verification,
}: SettingsAccountProps) {
  return (
    <>
      <Head title="Account Settings" />
      <SettingsLayout title="Account">
        <AccountForm user={user} avatarImages={avatar_images} />

        <div className="mt-8">
          <h3 className="text-lg font-medium mb-4">Verification</h3>
          <div className="space-y-6">
            <PhoneVerification verification={verification} />
            <IdUpload verification={verification} />
          </div>
        </div>
      </SettingsLayout>
    </>
  );
}
