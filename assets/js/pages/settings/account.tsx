import { Head } from "@inertiajs/react";
import { SettingsLayout, AccountForm } from "@/features/settings";
import type { SettingsUser } from "@/features/settings";

interface SettingsAccountProps {
  user: SettingsUser;
}

export default function SettingsAccount({ user }: SettingsAccountProps) {
  return (
    <>
      <Head title="Account Settings" />
      <SettingsLayout title="Account">
        <AccountForm user={user} />
      </SettingsLayout>
    </>
  );
}
