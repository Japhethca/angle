import { useState } from 'react';
import { Link, usePage } from '@inertiajs/react';
import { Search, Bell, Menu } from 'lucide-react';
import { useAuth, AuthLink } from '@/features/auth';
import { Button } from '@/components/ui/button';
import { Sheet, SheetTrigger, SheetContent, SheetHeader, SheetTitle } from '@/components/ui/sheet';
import {
  NavigationMenu,
  NavigationMenuList,
  NavigationMenuItem,
  NavigationMenuTrigger,
  NavigationMenuContent,
} from '@/components/ui/navigation-menu';
import { CategoryMegaMenu, type NavCategory } from './category-mega-menu';
import { UserMenuPopover } from './user-menu-popover';
import { UserMenuContent } from './user-menu-content';

interface MainNavProps {
  navCategories: NavCategory[];
}

const navLinks = [
  { label: 'Home', href: '/' },
  { label: 'My Bids', href: '/bids', auth: true },
  { label: 'Store', href: '/store', auth: true },
  { label: 'Watchlist', href: '/watchlist', auth: true },
];

export function MainNav({ navCategories }: MainNavProps) {
  const { authenticated } = useAuth();
  const { url } = usePage();
  const [mobileOpen, setMobileOpen] = useState(false);

  const visibleLinks = navLinks.filter(link => !link.auth || authenticated);

  const isActive = (href: string) => {
    if (href === '/') return url === '/';
    return url.startsWith(href);
  };

  const isCategoriesActive = url.startsWith('/categories');

  return (
    <nav className="sticky top-0 z-40 border-b border-subtle bg-surface">
      <div className="flex h-16 items-center justify-between px-4 lg:h-[72px] lg:px-10">
        {/* Left: Logo + Desktop nav links */}
        <div className="flex items-center gap-10">
          <Link href="/">
            <img src="/images/logo.svg" alt="Angle" className="h-8 dark:brightness-0 dark:invert" />
          </Link>

          {/* Desktop nav links */}
          <div className="hidden items-center gap-8 lg:flex">
            {/* Home link */}
            <AuthLink
              href="/"
              className={
                isActive('/')
                  ? 'border-b-2 border-primary-1000 dark:border-primary-600 pb-1 text-sm font-medium text-primary-1000 dark:text-primary-600'
                  : 'text-sm text-content-secondary transition-colors hover:text-content'
              }
            >
              Home
            </AuthLink>

            {/* Categories mega-menu */}
            <NavigationMenu viewport={false}>
              <NavigationMenuList>
                <NavigationMenuItem>
                  <NavigationMenuTrigger
                    className={
                      isCategoriesActive
                        ? 'h-auto rounded-none border-b-2 border-primary-1000 dark:border-primary-600 bg-transparent p-0 pb-1 text-sm font-medium text-primary-1000 dark:text-primary-600 shadow-none hover:bg-transparent focus:bg-transparent data-[state=open]:bg-transparent'
                        : 'h-auto rounded-none bg-transparent p-0 text-sm font-normal text-content-secondary shadow-none transition-colors hover:bg-transparent hover:text-content focus:bg-transparent data-[state=open]:bg-transparent'
                    }
                  >
                    Categories
                  </NavigationMenuTrigger>
                  <NavigationMenuContent className="md:w-[860px] rounded-b-xl border-0 bg-surface p-0 shadow-[0px_1px_2px_0px_rgba(0,0,0,0.08)]">
                    <CategoryMegaMenu categories={navCategories} />
                  </NavigationMenuContent>
                </NavigationMenuItem>
              </NavigationMenuList>
            </NavigationMenu>

            {/* Remaining nav links */}
            {visibleLinks
              .filter(link => link.href !== '/')
              .map(link => (
                <AuthLink
                  key={link.href}
                  href={link.href}
                  auth={link.auth}
                  className={
                    isActive(link.href)
                      ? 'border-b-2 border-primary-1000 dark:border-primary-600 pb-1 text-sm font-medium text-primary-1000 dark:text-primary-600'
                      : 'text-sm text-content-secondary transition-colors hover:text-content'
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
            <Search className="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-content-placeholder" />
            <input
              placeholder="Search for an item..."
              className="h-10 w-[358px] rounded-lg bg-surface-muted pl-10 pr-4 text-sm text-content placeholder:text-content-placeholder outline-none"
              disabled
            />
          </div>

          {authenticated ? (
            <>
              <button className="flex size-10 items-center justify-center rounded-lg text-content-secondary transition-colors hover:bg-surface-muted">
                <Bell className="size-5" />
              </button>
              <UserMenuPopover />
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

        {/* Mobile right section — unchanged */}
        <div className="flex items-center gap-2 lg:hidden">
          <button className="flex size-9 items-center justify-center rounded-lg bg-surface-muted text-content-secondary">
            <Search className="size-[18px]" />
          </button>
          {authenticated && (
            <button className="flex size-9 items-center justify-center rounded-lg bg-surface-muted text-content-secondary">
              <Bell className="size-[18px]" />
            </button>
          )}
          <Sheet open={mobileOpen} onOpenChange={setMobileOpen}>
            <SheetTrigger asChild>
              <button className="flex size-9 items-center justify-center rounded-lg bg-surface-muted text-content-secondary">
                <Menu className="size-[18px]" />
              </button>
            </SheetTrigger>
            <SheetContent side="right" className="w-full bg-surface sm:w-[300px]">
              <SheetHeader>
                <SheetTitle>
                  <img
                    src="/images/logo.svg"
                    alt="Angle"
                    className="h-8 dark:brightness-0 dark:invert"
                  />
                </SheetTitle>
              </SheetHeader>

              <div className="flex flex-col gap-6 px-4 pt-4">
                {authenticated ? (
                  <UserMenuContent onNavigate={() => setMobileOpen(false)} />
                ) : (
                  <div className="flex flex-col gap-2">
                    <Button variant="outline" asChild>
                      <Link href="/auth/login" onClick={() => setMobileOpen(false)}>
                        Sign In
                      </Link>
                    </Button>
                    <Button className="bg-primary-600 text-white hover:bg-primary-600/90" asChild>
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
