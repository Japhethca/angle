import { Head } from "@inertiajs/react";
import { SettingsLayout } from "@/features/settings";
import type { SettingsUser } from "@/features/settings";

interface SettingsPreferencesProps {
  user: SettingsUser;
}

export default function SettingsPreferences({ user }: SettingsPreferencesProps) {
  return (
    <>
      <Head title="Preferences" />
      <SettingsLayout title="Preferences">
        <div className="space-y-8">
          <p>Preferences settings coming soon.</p>
        </div>
      </SettingsLayout>
    </>
  );
}
