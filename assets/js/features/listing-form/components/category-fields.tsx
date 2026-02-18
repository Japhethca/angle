import { useMemo } from "react";
import { Loader2 } from "lucide-react";
import { listOptionSets, buildCSRFHeaders } from "@/ash_rpc";
import { useAshQuery } from "@/hooks/use-ash-query";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import type { CategoryField } from "../schemas/listing-form-schema";

interface CategoryFieldsProps {
  fields: CategoryField[];
  values: Record<string, string>;
  onChange: (key: string, value: string) => void;
}

export function CategoryFields({ fields, values, onChange }: CategoryFieldsProps) {
  // Collect all unique optionSetSlugs referenced by the fields
  const slugs = useMemo(
    () => [...new Set(fields.map((f) => f.optionSetSlug).filter(Boolean))] as string[],
    [fields]
  );

  // Lazy-load all referenced option sets in one query
  const { data: optionSets, isLoading: optionSetsLoading } = useAshQuery(
    ["optionSets", ...slugs],
    () =>
      listOptionSets({
        fields: ["id", "slug", { optionSetValues: ["value", "label", "sortOrder", "isActive"] }],
        filter: { slug: { in: slugs } },
        headers: buildCSRFHeaders(),
      }),
    { enabled: slugs.length > 0 }
  );

  // Build a lookup: slug -> sorted values
  const optionsBySlug = useMemo(() => {
    const map: Record<string, Array<{ value: string; label: string }>> = {};
    if (!optionSets) return map;

    for (const os of optionSets) {
      const activeValues = (os.optionSetValues || [])
        .filter((v: any) => v.isActive !== false)
        .sort((a: any, b: any) => (a.sortOrder ?? 0) - (b.sortOrder ?? 0));
      map[os.slug] = activeValues;
    }
    return map;
  }, [optionSets]);

  if (fields.length === 0) return null;

  return (
    <div className="space-y-4">
      <Label className="text-sm font-medium">Category Details</Label>
      <div className="grid gap-3 sm:grid-cols-2">
        {fields.map((field) => (
          <div key={field.name} className="space-y-1.5">
            <Label htmlFor={`attr-${field.name}`} className="text-xs text-content-secondary">
              {field.name}
              {field.required && <span className="text-feedback-error"> *</span>}
            </Label>

            {field.optionSetSlug ? (
              // Priority 1: Dropdown from lazy-loaded option set
              optionSetsLoading ? (
                <div className="flex h-10 items-center gap-2 rounded-md border border-input px-3">
                  <Loader2 className="size-3.5 animate-spin text-content-tertiary" />
                  <span className="text-xs text-content-tertiary">Loading options...</span>
                </div>
              ) : (
                <Select
                  value={values[field.name] || ""}
                  onValueChange={(v) => onChange(field.name, v)}
                >
                  <SelectTrigger>
                    <SelectValue placeholder={`Select ${field.name.toLowerCase()}`} />
                  </SelectTrigger>
                  <SelectContent>
                    {(optionsBySlug[field.optionSetSlug] || []).map((opt) => (
                      <SelectItem key={opt.value} value={opt.value}>
                        {opt.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              )
            ) : field.options && field.options.length > 0 ? (
              // Priority 2: Inline dropdown from options array
              <Select
                value={values[field.name] || ""}
                onValueChange={(v) => onChange(field.name, v)}
              >
                <SelectTrigger>
                  <SelectValue placeholder={`Select ${field.name.toLowerCase()}`} />
                </SelectTrigger>
                <SelectContent>
                  {field.options.map((opt) => (
                    <SelectItem key={opt} value={opt}>
                      {opt}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            ) : (
              // Priority 3: Free text input
              <Input
                id={`attr-${field.name}`}
                placeholder={field.description || `Enter ${field.name.toLowerCase()}`}
                value={values[field.name] || ""}
                onChange={(e) => onChange(field.name, e.target.value)}
              />
            )}

            {/* Description helper text (shown for all field types) */}
            {field.description && (
              <p className="text-xs text-content-tertiary">{field.description}</p>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}
