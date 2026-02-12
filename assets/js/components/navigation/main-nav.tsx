import { useState } from "react";
import { Link } from "@inertiajs/react";
import { Search, Bell, Menu, User } from "lucide-react";
import { useAuth } from "@/contexts/auth-context";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  Sheet,
  SheetTrigger,
  SheetContent,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";

const navLinks = [
  { label: "Home", href: "/", auth: false },
  { label: "Categories", href: "/categories", auth: false },
  { label: "My Bids", href: "/bids", auth: true },
  { label: "Sell Item", href: "/items/new", auth: true },
  { label: "Watchlist", href: "/watchlist", auth: true },
];

export function MainNav() {
  const { authenticated } = useAuth();
  const [mobileOpen, setMobileOpen] = useState(false);

  const visibleLinks = navLinks.filter(
    (link) => !link.auth || authenticated
  );

  return (
    <nav className="sticky top-0 z-40 border-b border-neutral-07 bg-white">
      <div className="mx-auto flex h-16 max-w-7xl items-center justify-between px-4 lg:px-8">
        {/* Logo */}
        <Link href="/" className="font-heading text-xl font-semibold text-primary-600">
          Angle
        </Link>

        {/* Desktop nav links */}
        <div className="hidden items-center gap-6 lg:flex">
          {visibleLinks.map((link) => (
            <Link
              key={link.href}
              href={link.href}
              className="text-sm text-neutral-03 transition-colors hover:text-neutral-01"
            >
              {link.label}
            </Link>
          ))}
        </div>

        {/* Desktop right section */}
        <div className="hidden items-center gap-3 lg:flex">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-neutral-05" />
            <Input
              placeholder="Search items..."
              className="h-9 w-[200px] pl-9"
              disabled
            />
          </div>

          {authenticated ? (
            <>
              <Button variant="ghost" size="icon" disabled>
                <Bell className="size-5 text-neutral-03" />
              </Button>
              <Button variant="ghost" size="icon" asChild>
                <Link href="/profile">
                  <User className="size-5 text-neutral-03" />
                </Link>
              </Button>
            </>
          ) : (
            <>
              <Button variant="ghost" size="sm" asChild>
                <Link href="/auth/login">Sign In</Link>
              </Button>
              <Button
                size="sm"
                className="bg-primary-600 text-white hover:bg-primary-600/90"
                asChild
              >
                <Link href="/auth/register">Sign Up</Link>
              </Button>
            </>
          )}
        </div>

        {/* Mobile hamburger */}
        <Sheet open={mobileOpen} onOpenChange={setMobileOpen}>
          <SheetTrigger asChild className="lg:hidden">
            <Button variant="ghost" size="icon">
              <Menu className="size-5" />
            </Button>
          </SheetTrigger>
          <SheetContent side="right" className="w-full bg-white sm:w-[300px]">
            <SheetHeader>
              <SheetTitle className="font-heading text-primary-600">
                Angle
              </SheetTitle>
            </SheetHeader>

            <div className="flex flex-col gap-6 px-4">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-neutral-05" />
                <Input
                  placeholder="Search items..."
                  className="pl-9"
                  disabled
                />
              </div>

              <div className="flex flex-col gap-3">
                {visibleLinks.map((link) => (
                  <Link
                    key={link.href}
                    href={link.href}
                    className="text-sm text-neutral-03 transition-colors hover:text-neutral-01"
                    onClick={() => setMobileOpen(false)}
                  >
                    {link.label}
                  </Link>
                ))}
              </div>

              {authenticated ? (
                <Link
                  href="/profile"
                  className="text-sm text-neutral-03 transition-colors hover:text-neutral-01"
                  onClick={() => setMobileOpen(false)}
                >
                  Profile
                </Link>
              ) : (
                <div className="flex flex-col gap-2">
                  <Button variant="outline" asChild>
                    <Link href="/auth/login" onClick={() => setMobileOpen(false)}>
                      Sign In
                    </Link>
                  </Button>
                  <Button
                    className="bg-primary-600 text-white hover:bg-primary-600/90"
                    asChild
                  >
                    <Link href="/auth/register" onClick={() => setMobileOpen(false)}>
                      Sign Up
                    </Link>
                  </Button>
                </div>
              )}
            </div>
          </SheetContent>
        </Sheet>
      </div>
    </nav>
  );
}
