import { useEffect } from "react";
import { usePage } from "@inertiajs/react";
import { toast } from "sonner";
import { Toaster } from "@/components/ui/sonner";
import { MainNav } from "../navigation/main-nav";
import { PageProps } from "../../types/auth";

interface LayoutProps {
  children: React.ReactNode;
}

export default function Layout({ children }: LayoutProps) {
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
    <>
      <MainNav />
      <main>{children}</main>
      <Toaster />
    </>
  );
}