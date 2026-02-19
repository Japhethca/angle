import { Link } from "@inertiajs/react";
import { Button } from "@/components/ui/button";

export function GuestHero() {
  return (
    <section className="relative overflow-hidden bg-gradient-to-br from-primary-600 to-primary-1000">
      {/* Decorative background pattern */}
      <div className="absolute inset-0 opacity-10">
        <div className="absolute left-1/4 top-1/4 size-64 rounded-full bg-primary-400 blur-3xl" />
        <div className="absolute bottom-1/4 right-1/4 size-48 rounded-full bg-primary-600 blur-3xl" />
      </div>

      <div className="relative px-4 py-16 text-center lg:px-10 lg:py-24">
        <h1 className="font-heading text-4xl font-bold text-white lg:text-6xl">
          Bid. Win. Own.
        </h1>
        <p className="mx-auto mt-4 max-w-xl text-lg text-white/80 lg:text-xl">
          Discover unique items at auction prices. Join thousands of bidders on
          Nigeria&apos;s premier auction platform.
        </p>
        <div className="mt-8 flex items-center justify-center gap-4">
          <Button
            size="lg"
            className="rounded-full bg-white px-8 text-primary-1000 shadow-lg transition-all hover:bg-gray-50 hover:shadow-xl"
            asChild
          >
            <Link href="/auth/register">Sign Up Free</Link>
          </Button>
          <Button
            variant="outline"
            size="lg"
            className="rounded-full border-2 border-white bg-transparent px-8 text-white shadow-md transition-all hover:bg-white/20"
            asChild
          >
            <Link href="#search-section">Browse Items</Link>
          </Button>
        </div>
      </div>
    </section>
  );
}
