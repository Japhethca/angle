import { Head } from "@inertiajs/react";
import { SettingsLayout, AccountForm } from "@/features/settings";

interface SettingsUser {
  id: string;
  email: string;
  full_name: string | null;
  phone_number: string | null;
  location: string | null;
}

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
