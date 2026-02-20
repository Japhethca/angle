import { useMemo, useState } from "react";
import { Check, MapPin, Search, ChevronsUpDown } from "lucide-react";
import { useAshQuery } from "@/hooks/use-ash-query";
import { readOptionSetWithDescendants, buildCSRFHeaders } from "@/ash_rpc";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";

interface LocationValue {
  state: string;
  lga?: string;
}

interface LocationOption {
  value: string;
  label: string;
  type: "state" | "lga";
  state?: string;
}

interface LocationComboboxProps {
  value?: LocationValue;
  onChange: (value: LocationValue) => void;
  error?: string;
}

export function LocationCombobox({
  value,
  onChange,
  error,
}: LocationComboboxProps) {
  const [open, setOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");

  const { data: optionSetData, isLoading } = useAshQuery(
    ["option-sets", "ng-states"],
    () =>
      readOptionSetWithDescendants({
        input: { slug: "ng-states" },
        fields: [
          "id",
          "name",
          "slug",
          {
            optionSetValues: ["id", "value", "label", "parentValue"],
          },
          {
            children: [
              "id",
              "name",
              {
                optionSetValues: ["id", "value", "label", "parentValue"],
              },
            ],
          },
        ],
        headers: buildCSRFHeaders(),
      })
  );

  const flattenedOptions = useMemo<LocationOption[]>(() => {
    // RPC returns an array - access first element
    const optionSet = optionSetData?.[0];
    if (!optionSet?.optionSetValues) return [];

    const states: LocationOption[] = optionSet.optionSetValues.map(
      (state) => ({
        value: state.value,
        label: state.label,
        type: "state" as const,
      })
    );

    const lgas: LocationOption[] =
      optionSet.children?.flatMap((child) =>
        child.optionSetValues.map((lga) => ({
          value: `${lga.parentValue}|${lga.value}`,
          label: `${lga.parentValue} → ${lga.label}`,
          type: "lga" as const,
          state: lga.parentValue || undefined,
        }))
      ) || [];

    return [...states, ...lgas];
  }, [optionSetData]);

  const filteredOptions = useMemo(() => {
    if (!searchQuery.trim()) return flattenedOptions;
    const q = searchQuery.toLowerCase();
    return flattenedOptions.filter(
      (opt) =>
        opt.label.toLowerCase().includes(q) ||
        opt.state?.toLowerCase().includes(q)
    );
  }, [flattenedOptions, searchQuery]);

  const displayValue = useMemo(() => {
    if (!value?.state) return "Select location...";
    if (value.lga) return `${value.state} → ${value.lga}`;
    return value.state;
  }, [value]);

  const selectedValue = useMemo(() => {
    if (!value?.state) return "";
    if (value.lga) return `${value.state}|${value.lga}`;
    return value.state;
  }, [value]);

  const handleSelect = (selectedValue: string) => {
    if (selectedValue.includes("|")) {
      const [state, lga] = selectedValue.split("|");
      onChange({ state, lga });
    } else {
      onChange({ state: selectedValue });
    }
    setOpen(false);
    setSearchQuery("");
  };

  const handleClose = () => {
    setOpen(false);
    setSearchQuery("");
  };

  if (isLoading) {
    return (
      <div className="flex items-center gap-2 text-sm text-content-tertiary">
        <MapPin className="size-4 animate-pulse" />
        Loading locations...
      </div>
    );
  }

  return (
    <div className="space-y-2">
      <Button
        type="button"
        variant="outline"
        role="combobox"
        aria-expanded={open}
        onClick={() => setOpen(true)}
        className={cn(
          "w-full justify-between font-normal",
          !value?.state && "text-content-tertiary",
          error && "border-destructive"
        )}
      >
        <span className="truncate">{displayValue}</span>
        <ChevronsUpDown className="ml-2 size-4 shrink-0 opacity-50" />
      </Button>

      <Dialog open={open} onOpenChange={handleClose}>
        <DialogContent className="max-h-[80vh] overflow-hidden p-0 sm:max-w-md">
          <DialogHeader className="border-b px-4 py-3">
            <DialogTitle className="text-base">Select Location</DialogTitle>
          </DialogHeader>

          {/* Search */}
          <div className="border-b px-4 py-2">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-content-tertiary" />
              <Input
                placeholder="Search state or LGA"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="pl-9"
              />
            </div>
          </div>

          {/* Options list */}
          <div className="max-h-[50vh] overflow-y-auto">
            {filteredOptions.length === 0 ? (
              <p className="p-4 text-center text-sm text-content-tertiary">
                No location found
              </p>
            ) : (
              filteredOptions.map((option) => (
                <button
                  key={option.value}
                  type="button"
                  onClick={() => handleSelect(option.value)}
                  className={cn(
                    "flex w-full items-center justify-between px-4 py-3 text-left text-sm hover:bg-surface-secondary",
                    option.type === "lga" && "pl-8"
                  )}
                >
                  <div className="flex items-center gap-2">
                    {option.type === "state" ? (
                      <span className="font-medium text-content">
                        {option.label}
                      </span>
                    ) : (
                      <>
                        <span className="text-content-tertiary">→</span>
                        <span className="text-content">{option.label}</span>
                        <span className="text-xs text-content-tertiary">
                          ({option.state})
                        </span>
                      </>
                    )}
                  </div>
                  {selectedValue === option.value && (
                    <Check className="size-4 text-primary-600" />
                  )}
                </button>
              ))
            )}
          </div>
        </DialogContent>
      </Dialog>

      {error && <p className="text-sm text-destructive">{error}</p>}
    </div>
  );
}
