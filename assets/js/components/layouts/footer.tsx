import { Link } from "@inertiajs/react";
import { Separator } from "@/components/ui/separator";

const goodsLinks = [
  { label: "All Categories", href: "/categories" },
  { label: "Ending Soon", href: "/#ending-soon" },
  { label: "Hot Items", href: "/#hot-now" },
  { label: "How It Works", href: "/how-it-works" },
];

const socialLinks = [
  { label: "Twitter", href: "#" },
  { label: "Instagram", href: "#" },
  { label: "Facebook", href: "#" },
];

const legalLinks = [
  { label: "Terms of Service", href: "/terms" },
  { label: "Privacy Policy", href: "/privacy" },
  { label: "Cookie Policy", href: "/cookies" },
];

export function Footer() {
  return (
    <footer className="bg-neutral-01 text-neutral-10">
      <div className="mx-auto max-w-7xl px-4 py-12 lg:px-8">
        <div className="grid gap-8 sm:grid-cols-2 lg:grid-cols-4">
          {/* Branding */}
          <div className="space-y-3">
            <h3 className="font-heading text-lg font-semibold text-primary-600">
              Angle
            </h3>
            <p className="text-sm text-neutral-05">
              Nigeria's premier auction platform. Buy and sell unique items through exciting bidding.
            </p>
          </div>

          {/* Goods */}
          <div className="space-y-3">
            <h4 className="text-sm font-medium text-neutral-06">Explore</h4>
            <ul className="space-y-2">
              {goodsLinks.map((link) => (
                <li key={link.label}>
                  <Link
                    href={link.href}
                    className="text-sm text-neutral-05 transition-colors hover:text-neutral-10"
                  >
                    {link.label}
                  </Link>
                </li>
              ))}
            </ul>
          </div>

          {/* Social */}
          <div className="space-y-3">
            <h4 className="text-sm font-medium text-neutral-06">Social</h4>
            <ul className="space-y-2">
              {socialLinks.map((link) => (
                <li key={link.label}>
                  <a
                    href={link.href}
                    className="text-sm text-neutral-05 transition-colors hover:text-neutral-10"
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
          <div className="space-y-3">
            <h4 className="text-sm font-medium text-neutral-06">Legal</h4>
            <ul className="space-y-2">
              {legalLinks.map((link) => (
                <li key={link.label}>
                  <Link
                    href={link.href}
                    className="text-sm text-neutral-05 transition-colors hover:text-neutral-10"
                  >
                    {link.label}
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        </div>

        <Separator className="my-8 bg-neutral-03" />

        <p className="text-center text-xs text-neutral-05">
          &copy; {new Date().getFullYear()} Angle. All rights reserved.
        </p>
      </div>
    </footer>
  );
}
