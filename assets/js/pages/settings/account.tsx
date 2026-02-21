import { Head } from "@inertiajs/react";
import { SettingsLayout, AccountForm } from "@/features/settings";
import { PhoneVerification, IdUpload } from "@/features/verification";
import type { SettingsUser } from "@/features/settings";
import type { ImageData } from "@/lib/image-url";

interface UserVerification {
  id: string;
  phone_verified: boolean;
  phone_verified_at: string | null;
  phone_number: string | null;
  id_document_url: string | null;
  id_verified: boolean;
  id_verification_status: "not_submitted" | "pending" | "approved" | "rejected";
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
            {verification && (
              <>
                <PhoneVerification
                  verificationId={verification.id}
                  initialPhoneNumber={user.phone_number}
                  phoneVerified={verification.phone_verified}
                  phoneVerifiedAt={verification.phone_verified_at}
                />
                <IdUpload
                  verificationId={verification.id}
                  idVerified={verification.id_verified}
                  idVerificationStatus={verification.id_verification_status}
                  idDocumentUrl={verification.id_document_url}
                />
              </>
            )}
          </div>
        </div>
      </SettingsLayout>
    </>
  );
}
