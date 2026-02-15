import { Head } from "@inertiajs/react";
import { SettingsLayout, ChangePasswordForm, TwoFactorSection } from "@/features/settings";
import type { SettingsUser } from "@/features/settings";

interface SettingsSecurityProps {
  user: SettingsUser;
}

export default function SettingsSecurity({ user }: SettingsSecurityProps) {
  return (
    <>
      <Head title="Security Settings" />
      <SettingsLayout title="Security">
        <div className="space-y-8">
          <ChangePasswordForm userId={user.id} />
          <TwoFactorSection />
        </div>
      </SettingsLayout>
    </>
  );
}
