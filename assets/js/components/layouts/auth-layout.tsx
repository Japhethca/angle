import { useEffect, type ReactNode } from "react";
import { usePage } from "@inertiajs/react";
import { toast } from "sonner";
import { Toaster } from "@/components/ui/sonner";
import type { PageProps } from "@/types/auth";

const CATEGORY_PILLS = [
  "Vehicles",
  "Cultural Artefacts",
  "Gadgets",
  "Home Appliances",
  "Rare Collectibles",
];

function AngleLogo({ className = "" }: { className?: string }) {
  return (
    <div className={`flex items-center ${className}`}>
      <img src="/images/logo.svg" alt="Angle" height="36" />
    </div>
  );
}

interface AuthLayoutProps {
  children: ReactNode;
  heroImage?: string;
}

export function AuthLayout({
  children,
  heroImage = "/images/auth-hero.png",
}: AuthLayoutProps) {
  const { flash } = usePage<PageProps>().props;

  useEffect(() => {
    if (flash.success) {
      toast.success(flash.success);
    }
    if (flash.info) {
      toast.info(flash.info);
    }
    if (flash.error) {
      toast.error(flash.error);
    }
  }, [flash]);

  return (
    <div className="flex min-h-screen">
      {/* Hero panel - hidden on mobile, visible on lg+ */}
      <div className="relative hidden lg:flex lg:w-1/2 lg:flex-col lg:justify-between">
        <img
          src={heroImage}
          alt=""
          className="absolute inset-0 h-full w-full object-cover"
        />
        {/* Dark overlay */}
        <div className="absolute inset-0 bg-black/50" />

        {/* Logo on hero */}
        <div className="relative z-10 p-8">
          <img
            src="/images/logo.svg"
            alt="Angle"
            height="36"
            className="brightness-0 invert"
          />
        </div>

        {/* Category pills at bottom of hero */}
        <div className="relative z-10 p-8">
          <div className="flex flex-wrap gap-2">
            {CATEGORY_PILLS.map((category) => (
              <span
                key={category}
                className="rounded-full border border-white/20 bg-white/10 px-4 py-1.5 text-sm font-medium text-white backdrop-blur-sm"
              >
                {category}
              </span>
            ))}
          </div>
        </div>
      </div>

      {/* Form panel */}
      <div className="flex w-full flex-col items-center justify-center px-6 py-12 lg:w-1/2 lg:px-12">
        {/* Mobile logo - hidden on lg+ */}
        <div className="mb-8 lg:hidden">
          <AngleLogo />
        </div>

        <div className="w-full max-w-md">{children}</div>
      </div>

      <Toaster />
    </div>
  );
}
