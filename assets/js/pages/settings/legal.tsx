import { Head } from "@inertiajs/react";
import { SettingsLayout, LegalContent } from "@/features/settings";

export default function SettingsLegal() {
  return (
    <>
      <Head title="Legal" />
      <SettingsLayout title="Legal">
        <LegalContent />
      </SettingsLayout>
    </>
  );
}
