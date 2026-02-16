import { useEffect, useRef, useState } from "react";
import { User } from "lucide-react";
import { Popover, PopoverTrigger, PopoverContent } from "@/components/ui/popover";
import { UserMenuContent } from "./user-menu-content";

const CLOSE_DELAY = 150;

export function UserMenuPopover() {
  const [open, setOpen] = useState(false);
  const closeTimeout = useRef<ReturnType<typeof setTimeout> | null>(null);

  function handleOpen() {
    if (closeTimeout.current) {
      clearTimeout(closeTimeout.current);
      closeTimeout.current = null;
    }
    setOpen(true);
  }

  function handleClose() {
    closeTimeout.current = setTimeout(() => setOpen(false), CLOSE_DELAY);
  }

  useEffect(() => {
    return () => {
      if (closeTimeout.current) clearTimeout(closeTimeout.current);
    };
  }, []);

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <div onMouseEnter={handleOpen} onMouseLeave={handleClose}>
        <PopoverTrigger asChild>
          <button
            aria-label="User menu"
            className="flex size-10 items-center justify-center rounded-lg text-content-secondary transition-colors hover:bg-surface-muted"
          >
            <User className="size-5" />
          </button>
        </PopoverTrigger>
      </div>
      <PopoverContent
        align="end"
        sideOffset={8}
        className="w-[304px] rounded-xl border-0 px-6 pb-10 pt-6 shadow-[0px_1px_2px_0px_rgba(0,0,0,0.08)]"
        onMouseEnter={handleOpen}
        onMouseLeave={handleClose}
      >
        <UserMenuContent onNavigate={() => setOpen(false)} />
      </PopoverContent>
    </Popover>
  );
}
