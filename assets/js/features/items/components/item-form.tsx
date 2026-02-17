import { useState } from "react";
import { router } from "@inertiajs/react";
import { Info } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { PermissionGuard, CanCreateItems, usePermissions } from "@/features/auth";
import { ItemImageManager } from "@/components/image-upload";
import type { ImageData } from "@/lib/image-url";

interface ItemFormProps {
  item?: {
    id: string;
    title: string;
    description: string;
    starting_price: number;
    publication_status: "draft" | "published";
    created_by_id: string;
    images?: ImageData[];
  };
}

export function ItemForm({ item }: ItemFormProps) {
  const { hasPermission, user } = usePermissions();
  const [formData, setFormData] = useState({
    title: item?.title || "",
    description: item?.description || "",
    starting_price: item?.starting_price || 0,
  });
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [images, setImages] = useState<ImageData[]>(item?.images ?? []);

  const isOwner = item ? item.created_by_id === user?.id : true;
  const canUpdate = hasPermission("update_own_items") && isOwner;
  const canPublish = hasPermission("publish_items") && isOwner;
  const canManageAll = hasPermission("manage_all_items");

  const handleSubmit = async (e: React.FormEvent, action: "save" | "publish" = "save") => {
    e.preventDefault();
    setIsSubmitting(true);

    try {
      if (item) {
        // Update existing item
        await router.put(`/api/items/${item.id}`, {
          ...formData,
          publication_status: action === "publish" ? "published" : item.publication_status,
        });
      } else {
        // Create new item
        await router.post("/api/items", {
          ...formData,
          publication_status: action === "publish" ? "published" : "draft",
        });
      }
    } catch (error) {
      console.error("Failed to save item:", error);
    } finally {
      setIsSubmitting(false);
    }
  };

  const handlePublish = (e: React.FormEvent) => {
    handleSubmit(e, "publish");
  };

  const canEdit = !item || canUpdate || canManageAll;

  return (
    <Card className="max-w-2xl mx-auto">
      <CardHeader>
        <CardTitle>{item ? "Edit Item" : "Create New Item"}</CardTitle>
        <CardDescription>
          {item ? "Update your auction item details" : "Create a new auction item"}
        </CardDescription>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit} className="space-y-6">
          <div>
            <label htmlFor="title" className="block text-sm font-medium text-content-secondary">
              Title
            </label>
            <Input
              id="title"
              type="text"
              value={formData.title}
              onChange={(e) => setFormData({ ...formData, title: e.target.value })}
              disabled={!canEdit}
              required
              className="mt-1"
            />
          </div>

          <div>
            <label htmlFor="description" className="block text-sm font-medium text-content-secondary">
              Description
            </label>
            <Textarea
              id="description"
              value={formData.description}
              onChange={(e) => setFormData({ ...formData, description: e.target.value })}
              disabled={!canEdit}
              rows={4}
              className="mt-1"
            />
          </div>

          <div>
            <label htmlFor="starting_price" className="block text-sm font-medium text-content-secondary">
              Starting Price ($)
            </label>
            <Input
              id="starting_price"
              type="number"
              step="0.01"
              min="0"
              value={formData.starting_price}
              onChange={(e) => setFormData({ ...formData, starting_price: parseFloat(e.target.value) || 0 })}
              disabled={!canEdit}
              required
              className="mt-1"
            />
          </div>

          {/* Image management -- only available in edit mode (needs item ID) */}
          {item ? (
            <ItemImageManager
              itemId={item.id}
              images={images}
              onImagesChange={setImages}
            />
          ) : (
            <div className="flex items-start gap-2 rounded-md border border-border bg-surface-muted p-4">
              <Info className="mt-0.5 size-4 shrink-0 text-content-tertiary" />
              <p className="text-sm text-content-secondary">
                Save your item first, then add images from the edit page.
              </p>
            </div>
          )}

          {item && (
            <div className="bg-surface-muted p-4 rounded-md">
              <h4 className="text-sm font-medium text-content">Current Status</h4>
              <p className="text-sm text-content-secondary mt-1">
                Status: <span className="font-medium">{item.publication_status}</span>
              </p>
            </div>
          )}

          {!canEdit && (
            <div className="bg-feedback-warning-muted border border-yellow-200 rounded-md p-4">
              <p className="text-sm text-feedback-warning">
                You don't have permission to edit this item.
              </p>
            </div>
          )}

          <div className="flex justify-end space-x-3">
            {/* Save as Draft - requires create_items or update_own_items permission */}
            <PermissionGuard 
              permissions={item ? ["update_own_items", "manage_all_items"] : ["create_items"]}
              requireAll={false}
            >
              <Button
                type="submit"
                variant="outline"
                disabled={!canEdit || isSubmitting}
              >
                {isSubmitting ? "Saving..." : "Save Draft"}
              </Button>
            </PermissionGuard>

            {/* Publish - requires publish_items permission */}
            <PermissionGuard 
              permissions={["publish_items", "manage_all_items"]}
              requireAll={false}
            >
              <Button
                type="button"
                onClick={handlePublish}
                disabled={!canEdit || !canPublish || isSubmitting}
              >
                {isSubmitting ? "Publishing..." : "Publish Item"}
              </Button>
            </PermissionGuard>
          </div>
        </form>

        {/* Admin-only actions */}
        <PermissionGuard permission="manage_all_items">
          <div className="mt-8 pt-6 border-t border-subtle">
            <h4 className="text-sm font-medium text-content mb-4">Admin Actions</h4>
            <div className="flex space-x-3">
              <Button variant="destructive" size="sm">
                Force Delete
              </Button>
              <Button variant="outline" size="sm">
                Change Owner
              </Button>
            </div>
          </div>
        </PermissionGuard>
      </CardContent>
    </Card>
  );
}