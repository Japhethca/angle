import { Head } from "@inertiajs/react";

export default function Profile() {
  return (
    <>
      <Head title="Profile" />
      <div className="flex min-h-[60vh] items-center justify-center">
        <div className="text-center">
          <h1 className="text-2xl font-bold text-content">Profile</h1>
          <p className="mt-2 text-sm text-content-tertiary">Coming soon</p>
        </div>
      </div>
    </>
  );
}
