import { Check } from "lucide-react";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";

interface ItemDetailTabsProps {
  description: string | null;
  attributes?: Record<string, any> | null;
}

const TAB_ITEMS = [
  { value: "description", label: "Description" },
  { value: "features", label: "Features" },
  { value: "authenticity", label: "Authenticity" },
  { value: "logistics", label: "Logistics" },
  { value: "warranty", label: "Warranty" },
  { value: "returns", label: "Returns" },
] as const;

export function ItemDetailTabs({ description, attributes }: ItemDetailTabsProps) {
  const attrs = (attributes || {}) as Record<string, string>;

  // Category-specific attributes (non-underscore-prefixed, non-empty)
  const categoryAttrs = Object.entries(attrs)
    .filter(([key, val]) => !key.startsWith("_") && val)
    .map(([key, val]) => ({ key: humanizeKey(key), value: val }));

  // Custom features from _customFeatures
  const customFeatures = attrs._customFeatures
    ? attrs._customFeatures.split("|||").filter(Boolean)
    : [];

  const hasFeatures = categoryAttrs.length > 0 || customFeatures.length > 0;

  return (

    <>
      {/* Desktop: tabbed layout */}
      <div className="hidden lg:block">
        <Tabs defaultValue="description">
          <TabsList className="w-full bg-surface-muted">
            {TAB_ITEMS.map((tab) => (
              <TabsTrigger key={tab.value} value={tab.value}>
                {tab.label}
              </TabsTrigger>
            ))}
          </TabsList>

          <TabsContent value="description" className="mt-4">
            <div className="text-sm leading-relaxed text-content-secondary">
              {description || "No description provided."}
            </div>
          </TabsContent>

          <TabsContent value="features" className="mt-4">
            {hasFeatures ? (
              <div className="space-y-4">
                {categoryAttrs.length > 0 && (
                  <dl className="grid grid-cols-2 gap-x-6 gap-y-3">
                    {categoryAttrs.map(({ key, value }) => (
                      <div key={key}>
                        <dt className="text-xs text-content-tertiary">{key}</dt>
                        <dd className="text-sm font-medium text-content">{value}</dd>
                      </div>
                    ))}
                  </dl>
                )}
                {categoryAttrs.length > 0 && customFeatures.length > 0 && (
                  <hr className="border-border" />
                )}
                {customFeatures.length > 0 && (
                  <ul className="space-y-2">
                    {customFeatures.map((f, i) => (
                      <li key={i} className="flex items-center gap-2 text-sm text-content-secondary">
                        <Check className="size-4 shrink-0 text-primary-600" />
                        {f}
                      </li>
                    ))}
                  </ul>
                )}
              </div>
            ) : (
              <p className="text-sm text-content-tertiary">
                No features listed for this item.
              </p>
            )}
          </TabsContent>

          <TabsContent value="authenticity" className="mt-4">
            <p className="text-sm text-content-tertiary">
              Authenticity verification details will be available soon.
            </p>
          </TabsContent>

          <TabsContent value="logistics" className="mt-4">
            <p className="text-sm text-content-tertiary">
              Shipping and logistics information will be available soon.
            </p>
          </TabsContent>

          <TabsContent value="warranty" className="mt-4">
            <p className="text-sm text-content-tertiary">
              Warranty information will be available soon.
            </p>
          </TabsContent>

          <TabsContent value="returns" className="mt-4">
            <p className="text-sm text-content-tertiary">
              Returns policy will be available soon.
            </p>
          </TabsContent>
        </Tabs>
      </div>

      {/* Mobile: linear sections */}
      <div className="space-y-6 lg:hidden">
        <section>
          <h3 className="mb-2 font-heading text-sm font-medium text-content">
            Description
          </h3>
          <div className="text-sm leading-relaxed text-content-secondary">
            {description || "No description provided."}
          </div>
        </section>

        <section>
          <h3 className="mb-2 font-heading text-sm font-medium text-content">
            Features
          </h3>
          {hasFeatures ? (
            <div className="space-y-3">
              {categoryAttrs.length > 0 && (
                <dl className="grid grid-cols-2 gap-x-4 gap-y-2">
                  {categoryAttrs.map(({ key, value }) => (
                    <div key={key}>
                      <dt className="text-xs text-content-tertiary">{key}</dt>
                      <dd className="text-sm font-medium text-content">{value}</dd>
                    </div>
                  ))}
                </dl>
              )}
              {categoryAttrs.length > 0 && customFeatures.length > 0 && (
                <hr className="border-border" />
              )}
              {customFeatures.length > 0 && (
                <ul className="space-y-2">
                  {customFeatures.map((f, i) => (
                    <li key={i} className="flex items-center gap-2 text-sm text-content-secondary">
                      <Check className="size-4 shrink-0 text-primary-600" />
                      {f}
                    </li>
                  ))}
                </ul>
              )}
            </div>
          ) : (
            <p className="text-sm text-content-tertiary">
              No features listed for this item.
            </p>
          )}
        </section>

        <section>
          <h3 className="mb-2 font-heading text-sm font-medium text-content">
            Authenticity
          </h3>
          <p className="text-sm text-content-tertiary">
            Authenticity verification details will be available soon.
          </p>
        </section>

        <section>
          <h3 className="mb-2 font-heading text-sm font-medium text-content">
            Logistics
          </h3>
          <p className="text-sm text-content-tertiary">
            Shipping and logistics information will be available soon.
          </p>
        </section>

        <section>
          <h3 className="mb-2 font-heading text-sm font-medium text-content">
            Warranty
          </h3>
          <p className="text-sm text-content-tertiary">
            Warranty information will be available soon.
          </p>
        </section>

        <section>
          <h3 className="mb-2 font-heading text-sm font-medium text-content">
            Returns
          </h3>
          <p className="text-sm text-content-tertiary">
            Returns policy will be available soon.
          </p>
        </section>
      </div>
    </>
  );
}

function humanizeKey(key: string): string {
  return key
    .replace(/([a-z])([A-Z])/g, "$1 $2")
    .replace(/_/g, " ")
    .replace(/\b\w/g, (c) => c.toUpperCase());
}
