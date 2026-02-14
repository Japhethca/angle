import { useEffect } from "react";
import { usePage } from "@inertiajs/react";
import { toast } from "sonner";
import { Toaster } from "@/components/ui/sonner";
import { MainNav } from "@/navigation/main-nav";
import { BottomNav } from "@/navigation/bottom-nav";
import { Footer } from "./footer";
import type { PageProps } from "@/features/auth";

interface LayoutProps {
  children: React.ReactNode;
}

export default function Layout({ children }: LayoutProps) {
  const { flash, nav_categories } = usePage<PageProps>().props;

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
    <div className="flex min-h-screen flex-col">
      <MainNav navCategories={nav_categories ?? []} />
      <main className="flex-1 pb-[72px] lg:pb-0">{children}</main>
      <Footer />
      <BottomNav />
      <Toaster />
    </div>
  );
}
