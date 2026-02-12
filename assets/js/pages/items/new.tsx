import { Head } from "@inertiajs/react";

export default function NewItem() {
  return (
    <>
      <Head title="Sell Item" />
      <div className="flex min-h-[60vh] items-center justify-center">
        <div className="text-center">
          <h1 className="text-2xl font-bold text-neutral-01">Sell Item</h1>
          <p className="mt-2 text-sm text-neutral-04">Coming soon</p>
        </div>
      </div>
    </>
  );
}
