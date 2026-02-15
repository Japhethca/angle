import { Head } from "@inertiajs/react";
import { SettingsLayout, SupportContent } from "@/features/settings";

export default function SettingsSupport() {
  return (
    <>
      <Head title="Support" />
      <SettingsLayout title="Support">
        <SupportContent />
      </SettingsLayout>
    </>
  );
}
