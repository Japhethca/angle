import type { ReactNode } from "react";

const CATEGORY_PILLS = [
  "Vehicles",
  "Cultural Artefacts",
  "Gadgets",
  "Home Appliances",
  "Rare Collectibles",
];

function AngleLogo({ className = "" }: { className?: string }) {
  return (
    <div className={`flex items-center gap-2 ${className}`}>
      <svg
        width="32"
        height="32"
        viewBox="0 0 24 24"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
      >
        <path
          d="M6 2L3 6V20C3 20.5304 3.21071 21.0391 3.58579 21.4142C3.96086 21.7893 4.46957 22 5 22H19C19.5304 22 20.0391 21.7893 20.4142 21.4142C20.7893 21.0391 21 20.5304 21 20V6L18 2H6Z"
          stroke="#F97316"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
        <path
          d="M3 6H21"
          stroke="#F97316"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
        <path
          d="M16 10C16 11.0609 15.5786 12.0783 14.8284 12.8284C14.0783 13.5786 13.0609 14 12 14C10.9391 14 9.92172 13.5786 9.17157 12.8284C8.42143 12.0783 8 11.0609 8 10"
          stroke="#F97316"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
      <span className="text-xl font-bold tracking-wide text-gray-900">
        ANGLE
      </span>
    </div>
  );
}

interface AuthLayoutProps {
  children: ReactNode;
  heroImage?: string;
}

export function AuthLayout({
  children,
  heroImage = "/images/auth-hero.jpg",
}: AuthLayoutProps) {
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
          <div className="flex items-center gap-2">
            <svg
              width="32"
              height="32"
              viewBox="0 0 24 24"
              fill="none"
              xmlns="http://www.w3.org/2000/svg"
            >
              <path
                d="M6 2L3 6V20C3 20.5304 3.21071 21.0391 3.58579 21.4142C3.96086 21.7893 4.46957 22 5 22H19C19.5304 22 20.0391 21.7893 20.4142 21.4142C20.7893 21.0391 21 20.5304 21 20V6L18 2H6Z"
                stroke="#F97316"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
              <path
                d="M3 6H21"
                stroke="#F97316"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
              <path
                d="M16 10C16 11.0609 15.5786 12.0783 14.8284 12.8284C14.0783 13.5786 13.0609 14 12 14C10.9391 14 9.92172 13.5786 9.17157 12.8284C8.42143 12.0783 8 11.0609 8 10"
                stroke="#F97316"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
            <span className="text-xl font-bold tracking-wide text-white">
              ANGLE
            </span>
          </div>
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
    </div>
  );
}
