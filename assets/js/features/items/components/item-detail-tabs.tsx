import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";

interface ItemDetailTabsProps {
  description: string | null;
}

const TAB_ITEMS = [
  { value: "description", label: "Description" },
  { value: "features", label: "Features" },
  { value: "authenticity", label: "Authenticity" },
  { value: "logistics", label: "Logistics" },
  { value: "warranty", label: "Warranty" },
  { value: "returns", label: "Returns" },
] as const;

export function ItemDetailTabs({ description }: ItemDetailTabsProps) {
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
            <p className="text-sm text-content-tertiary">
              Feature details will be available soon.
            </p>
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
          <p className="text-sm text-content-tertiary">
            Feature details will be available soon.
          </p>
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
