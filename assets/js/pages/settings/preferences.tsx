import { Head } from "@inertiajs/react";
import { SettingsLayout, PreferencesForm } from "@/features/settings";
import type { SettingsUser } from "@/features/settings";

interface SettingsPreferencesProps {
  user: SettingsUser;
}

export default function SettingsPreferences({ user }: SettingsPreferencesProps) {
  return (
    <>
      <Head title="Preferences" />
      <SettingsLayout title="Preferences">
        <PreferencesForm />
      </SettingsLayout>
    </>
  );
}
