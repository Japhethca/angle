import { useState } from "react";
import { Link, usePage } from "@inertiajs/react";
import { Search, Bell, Menu, User } from "lucide-react";
import { useAuth } from "@/contexts/auth-context";
import { Button } from "@/components/ui/button";
import {
  Sheet,
  SheetTrigger,
  SheetContent,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import { AuthLink } from "@/components/navigation/auth-link";

const navLinks = [
  { label: "Home", href: "/" },
  { label: "Categories", href: "/categories" },
  { label: "My Bids", href: "/bids", auth: true },
  { label: "Sell Item", href: "/items/new", auth: true },
  { label: "Watchlist", href: "/watchlist", auth: true },
];

export function MainNav() {
  const { authenticated } = useAuth();
  const { url } = usePage();
  const [mobileOpen, setMobileOpen] = useState(false);

  const visibleLinks = navLinks.filter(
    (link) => !link.auth || authenticated
  );

  const isActive = (href: string) => {
    if (href === "/") return url === "/";
    return url.startsWith(href);
  };

  return (
    <nav className="sticky top-0 z-40 border-b border-neutral-07 bg-white">
      <div className="flex h-16 items-center justify-between px-4 lg:h-[72px] lg:px-10">
        {/* Left: Logo + Desktop nav links */}
        <div className="flex items-center gap-10">
          <Link href="/">
            <img src="/images/logo.svg" alt="Angle" className="h-8" />
          </Link>

          {/* Desktop nav links */}
          <div className="hidden items-center gap-8 lg:flex">
            {visibleLinks.map((link) => (
              <AuthLink
                key={link.href}
                href={link.href}
                auth={link.auth}
                className={
                  isActive(link.href)
                    ? "border-b-2 border-primary-1000 pb-1 text-sm font-medium text-primary-1000"
                    : "text-sm text-neutral-03 transition-colors hover:text-neutral-01"
                }
              >
                {link.label}
              </AuthLink>
            ))}
          </div>
        </div>

        {/* Desktop right section */}
        <div className="hidden items-center gap-3 lg:flex">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-neutral-05" />
            <input
              placeholder="Search for an item..."
              className="h-10 w-[358px] rounded-lg bg-neutral-08 pl-10 pr-4 text-sm text-neutral-01 placeholder:text-neutral-05 outline-none"
              disabled
            />
          </div>

          {authenticated ? (
            <>
              <button className="flex size-10 items-center justify-center rounded-lg text-neutral-03 transition-colors hover:bg-neutral-08">
                <Bell className="size-5" />
              </button>
              <Link
                href="/profile"
                className="flex size-10 items-center justify-center rounded-lg text-neutral-03 transition-colors hover:bg-neutral-08"
              >
                <User className="size-5" />
              </Link>
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

        {/* Mobile right section */}
        <div className="flex items-center gap-2 lg:hidden">
          <button className="flex size-9 items-center justify-center rounded-lg bg-neutral-08 text-neutral-03">
            <Search className="size-[18px]" />
          </button>
          {authenticated && (
            <button className="flex size-9 items-center justify-center rounded-lg bg-neutral-08 text-neutral-03">
              <Bell className="size-[18px]" />
            </button>
          )}
          <Sheet open={mobileOpen} onOpenChange={setMobileOpen}>
            <SheetTrigger asChild>
              <button className="flex size-9 items-center justify-center rounded-lg bg-neutral-08 text-neutral-03">
                <Menu className="size-[18px]" />
              </button>
            </SheetTrigger>
            <SheetContent side="right" className="w-full bg-white sm:w-[300px]">
              <SheetHeader>
                <SheetTitle>
                  <img src="/images/logo.svg" alt="Angle" className="h-8" />
                </SheetTitle>
              </SheetHeader>

              <div className="flex flex-col gap-6 px-4 pt-4">
                {authenticated ? (
                  <Link
                    href="/profile"
                    className="text-sm font-medium text-neutral-01"
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
      </div>
    </nav>
  );
}
