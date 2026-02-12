import { Link } from "@inertiajs/react";

const categoryLinks = [
  { label: "Cultural Artifacts", href: "/categories" },
  { label: "Gadgets", href: "/categories" },
  { label: "Rare Collectibles", href: "/categories" },
  { label: "Home Appliances", href: "/categories" },
  { label: "Vehicles", href: "/categories" },
];

const socialLinks = [
  { label: "X", href: "#" },
  { label: "Instagram", href: "#" },
  { label: "LinkedIn", href: "#" },
];

const legalLinks = [
  { label: "Terms", href: "/terms" },
  { label: "Privacy policy", href: "/privacy" },
];

export function Footer() {
  return (
    <footer className="hidden bg-[#060818] text-white lg:block">
      <div className="px-10 py-12">
        <div className="grid grid-cols-12 gap-8">
          {/* Branding */}
          <div className="col-span-4 space-y-4">
            <img src="/images/logo.svg" alt="Angle" className="h-10 brightness-0 invert" />
            <p className="text-sm text-neutral-05">
              Nigeria's First Bidding Marketplace
            </p>
          </div>

          {/* Categories */}
          <div className="col-span-3 space-y-4">
            <h4 className="text-sm font-medium text-neutral-05">Categories</h4>
            <ul className="space-y-2.5">
              {categoryLinks.map((link) => (
                <li key={link.label}>
                  <Link
                    href={link.href}
                    className="text-sm text-neutral-06 transition-colors hover:text-white"
                  >
                    {link.label}
                  </Link>
                </li>
              ))}
            </ul>
          </div>

          {/* Socials */}
          <div className="col-span-2 space-y-4">
            <h4 className="text-sm font-medium text-neutral-05">Socials</h4>
            <ul className="space-y-2.5">
              {socialLinks.map((link) => (
                <li key={link.label}>
                  <a
                    href={link.href}
                    className="text-sm text-neutral-06 transition-colors hover:text-white"
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    {link.label}
                  </a>
                </li>
              ))}
            </ul>
          </div>

          {/* Legal */}
          <div className="col-span-3 space-y-4">
            <h4 className="text-sm font-medium text-neutral-05">Legal</h4>
            <ul className="space-y-2.5">
              {legalLinks.map((link) => (
                <li key={link.label}>
                  <Link
                    href={link.href}
                    className="text-sm text-neutral-06 transition-colors hover:text-white"
                  >
                    {link.label}
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        </div>

        {/* Copyright */}
        <div className="mt-12 border-t border-white/10 pt-6">
          <p className="text-xs text-neutral-05">
            &copy;{new Date().getFullYear()} Angle. All rights reserved.
          </p>
        </div>
      </div>
    </footer>
  );
}
