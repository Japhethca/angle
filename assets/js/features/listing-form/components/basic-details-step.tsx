import { useState, useMemo, useCallback, useEffect } from "react";
import { useForm, Controller } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { ChevronDown, Upload } from "lucide-react";
import { toast } from "sonner";
import { createDraftItem, updateDraftItem, buildCSRFHeaders, getPhoenixCSRFToken } from "@/ash_rpc";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { CategoryPicker } from "./category-picker";
import { CategoryFields } from "./category-fields";
import { FeatureFields } from "./feature-fields";
import {
  basicDetailsSchema,
  type BasicDetailsData,
  type ListingFormState,
} from "../schemas/listing-form-schema";
import type { Category } from "./listing-wizard";

interface BasicDetailsStepProps {
  categories: Category[];
  defaultValues: BasicDetailsData;
  defaultImages: File[];
  draftItemId: string | null;
  uploadedImages: ListingFormState["uploadedImages"];
  onNext: (data: BasicDetailsData, draftId: string, uploadedImages: ListingFormState["uploadedImages"]) => void;
  onDeleteImage: (imageId: string) => void;
}

export function BasicDetailsStep({
  categories,
  defaultValues,
  defaultImages,
  draftItemId,
  uploadedImages: existingUploaded,
  onNext,
  onDeleteImage,
}: BasicDetailsStepProps) {
  const [pickerOpen, setPickerOpen] = useState(false);
  const [categoryName, setCategoryName] = useState(() => {
    if (defaultValues.subcategoryId || defaultValues.categoryId) {
      return findCategoryName(categories, defaultValues.categoryId, defaultValues.subcategoryId);
    }
    return "";
  });
  const [attributes, setAttributes] = useState<Record<string, string>>(defaultValues.attributes);
  const [customFeatures, setCustomFeatures] = useState<string[]>(defaultValues.customFeatures);
  const [selectedImages, setSelectedImages] = useState<File[]>(defaultImages);
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Memoize object URLs and revoke on cleanup to prevent memory leaks
  const imageUrls = useMemo(() => selectedImages.map((f) => URL.createObjectURL(f)), [selectedImages]);
  useEffect(() => {
    return () => imageUrls.forEach((url) => URL.revokeObjectURL(url));
  }, [imageUrls]);

  const {
    register,
    handleSubmit,
    control,
    setValue,
    watch,
    formState: { errors },
  } = useForm<BasicDetailsData>({
    resolver: zodResolver(basicDetailsSchema),
    defaultValues,
  });

  const watchCategoryId = watch("categoryId");
  const watchSubcategoryId = watch("subcategoryId");

  // Get the selected (sub)category's attributeSchema (now a flat CategoryField[])
  const categoryFields = useMemo(() => {
    const subcatId = watchSubcategoryId;
    const catId = watchCategoryId;
    if (!catId) return [];

    for (const cat of categories) {
      if (cat.id === catId && !subcatId) {
        return cat.attributeSchema || [];
      }
      for (const sub of cat.categories) {
        if (sub.id === subcatId) {
          return sub.attributeSchema || [];
        }
      }
    }
    return [];
  }, [categories, watchCategoryId, watchSubcategoryId]);

  const handleCategorySelect = useCallback(
    (parentId: string, subId: string, name: string) => {
      setValue("categoryId", subId || parentId, { shouldValidate: true });
      setValue("subcategoryId", subId);
      setCategoryName(name);
      setAttributes({});
    },
    [setValue]
  );

  const handleImageSelect = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(e.target.files || []);
    e.target.value = "";
    const total = selectedImages.length + existingUploaded.length + files.length;
    if (total > 10) {
      toast.error("Maximum 10 images allowed");
      return;
    }
    setSelectedImages((prev) => [...prev, ...files]);
  }, [selectedImages, existingUploaded]);

  const removeSelectedImage = useCallback((index: number) => {
    setSelectedImages((prev) => prev.filter((_, i) => i !== index));
  }, []);

  const [deletingImageId, setDeletingImageId] = useState<string | null>(null);

  const handleDeleteUploadedImage = useCallback(async (imageId: string) => {
    setDeletingImageId(imageId);
    try {
      const csrfToken = getPhoenixCSRFToken();
      const res = await fetch(`/uploads/${imageId}`, {
        method: "DELETE",
        headers: csrfToken ? { "X-CSRF-Token": csrfToken } : {},
      });
      if (!res.ok) throw new Error("Failed to delete image");
      onDeleteImage(imageId);
    } catch {
      toast.error("Failed to delete image");
    } finally {
      setDeletingImageId(null);
    }
  }, [onDeleteImage]);

  const onSubmit = async (data: BasicDetailsData) => {
    setIsSubmitting(true);

    try {
      // Merge attributes + custom features
      const mergedAttributes = { ...attributes };
      const nonEmptyFeatures = customFeatures.filter((f) => f.trim());
      if (nonEmptyFeatures.length > 0) {
        mergedAttributes._customFeatures = nonEmptyFeatures.join("|||");
      }

      const submitData = { ...data, attributes: mergedAttributes, customFeatures: nonEmptyFeatures };

      let itemId = draftItemId;
      let currentUploaded = existingUploaded;

      if (!itemId) {
        // Create the draft
        const result = await createDraftItem({
          input: {
            title: data.title,
            description: data.description || undefined,
            startingPrice: "1", // Placeholder, will be updated in Step 2
            categoryId: data.categoryId || undefined,
            condition: data.condition,
            attributes: mergedAttributes,
          },
          fields: ["id"],
          headers: buildCSRFHeaders(),
        });

        if (!result.success) {
          throw new Error(result.errors.map((e) => e.message).join("; "));
        }

        itemId = result.data.id;
      } else {
        // Update existing draft with latest basic details
        const result = await updateDraftItem({
          identity: itemId,
          input: {
            id: itemId,
            title: data.title,
            description: data.description || undefined,
            categoryId: data.categoryId || undefined,
            condition: data.condition,
            attributes: mergedAttributes,
          },
          headers: buildCSRFHeaders(),
        });

        if (!result.success) {
          throw new Error(result.errors.map((e) => e.message).join("; "));
        }
      }

      // Upload images
      if (selectedImages.length > 0) {
        const newUploaded = await uploadImages(itemId, selectedImages);
        currentUploaded = [...existingUploaded, ...newUploaded];
      }

      onNext(submitData, itemId, currentUploaded);
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to save draft");
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-5">
      {/* Title */}
      <div className="space-y-1.5">
        <Label htmlFor="title">Item Title</Label>
        <Input
          id="title"
          placeholder="e.g., Apple iPhone 13 Pro, 128GB, Blue"
          {...register("title")}
        />
        {errors.title && (
          <p className="text-xs text-feedback-error">{errors.title.message}</p>
        )}
      </div>

      {/* Description */}
      <div className="space-y-1.5">
        <Label htmlFor="description">Description</Label>
        <Textarea
          id="description"
          placeholder="Write a detailed description of your item, why someone should buy it and any extra note."
          rows={4}
          {...register("description")}
        />
      </div>

      {/* Category + Condition side-by-side */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {/* Category picker */}
        <div className="space-y-1.5">
          <Label>Item Category</Label>
          <button
            type="button"
            onClick={() => setPickerOpen(true)}
            className="flex w-full items-center justify-between rounded-md border border-input bg-surface px-3 py-2 text-sm ring-offset-background focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
          >
            <span className={categoryName ? "text-content" : "text-content-tertiary"}>
              {categoryName || "Select a category"}
            </span>
            <ChevronDown className="size-4 text-content-tertiary" />
          </button>
          <p className="text-xs text-content-tertiary">
            Choose the category that best fits your item
          </p>
          {errors.categoryId && (
            <p className="text-xs text-feedback-error">{errors.categoryId.message}</p>
          )}
          <CategoryPicker
            open={pickerOpen}
            onOpenChange={setPickerOpen}
            categories={categories}
            selectedCategoryId={watchCategoryId}
            selectedSubcategoryId={watchSubcategoryId || ""}
            onSelect={handleCategorySelect}
          />
        </div>

        {/* Condition */}
        <div className="space-y-1.5">
          <Label>Item Condition</Label>
          <Controller
            name="condition"
            control={control}
            render={({ field }) => (
              <Select value={field.value} onValueChange={field.onChange}>
                <SelectTrigger>
                  <SelectValue placeholder="Select condition" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="new">New</SelectItem>
                  <SelectItem value="used">Fairly Used</SelectItem>
                  <SelectItem value="refurbished">Refurbished</SelectItem>
                </SelectContent>
              </Select>
            )}
          />
        </div>
      </div>

      {/* Category-specific fields */}
      {categoryFields.length > 0 && (
        <CategoryFields
          fields={categoryFields}
          values={attributes}
          onChange={(key, value) =>
            setAttributes((prev) => ({ ...prev, [key]: value }))
          }
        />
      )}

      {/* Features */}
      <FeatureFields features={customFeatures} onChange={setCustomFeatures} />

      {/* Photo upload */}
      <div className="space-y-3">
        <Label>Add Product Photos</Label>

        {/* Preview existing uploaded images */}
        {existingUploaded.length > 0 && (
          <div className="grid grid-cols-4 gap-2">
            {existingUploaded.map((img) => (
              <div key={img.id} className="group relative aspect-square overflow-hidden rounded-md bg-surface-muted">
                <img
                  src={img.variants.thumbnail || img.variants.original}
                  alt=""
                  className="size-full object-cover"
                />
                <button
                  type="button"
                  disabled={deletingImageId === img.id}
                  onClick={() => handleDeleteUploadedImage(img.id)}
                  className="absolute right-1 top-1 flex size-5 items-center justify-center rounded-full bg-black/60 text-xs text-white opacity-0 transition-opacity group-hover:opacity-100 [@media(hover:none)]:opacity-100 disabled:opacity-50"
                >
                  {deletingImageId === img.id ? "..." : "\u00d7"}
                </button>
              </div>
            ))}
          </div>
        )}

        {/* Preview selected files */}
        {selectedImages.length > 0 && (
          <div className="grid grid-cols-4 gap-2">
            {selectedImages.map((file, idx) => (
              <div key={idx} className="group relative aspect-square overflow-hidden rounded-md bg-surface-muted">
                <img
                  src={imageUrls[idx]}
                  alt=""
                  className="size-full object-cover"
                />
                <button
                  type="button"
                  onClick={() => removeSelectedImage(idx)}
                  className="absolute right-1 top-1 flex size-5 items-center justify-center rounded-full bg-black/60 text-xs text-white opacity-0 transition-opacity group-hover:opacity-100 [@media(hover:none)]:opacity-100"
                >
                  &times;
                </button>
              </div>
            ))}
          </div>
        )}

        {/* Upload area */}
        {existingUploaded.length + selectedImages.length < 10 && (
          <label className="flex cursor-pointer flex-col items-center gap-2 rounded-lg border-2 border-dashed border-border p-6 text-center transition-colors hover:border-primary-600/50 hover:bg-surface-secondary">
            <Upload className="size-8 text-content-tertiary" />
            <div>
              <span className="text-sm font-medium text-primary-600">Click to upload</span>
              <span className="text-sm text-content-tertiary"> or drag and drop</span>
            </div>
            <span className="text-xs text-content-tertiary">PNG, JPG up to 10MB</span>
            <input
              type="file"
              accept="image/*"
              multiple
              className="hidden"
              onChange={handleImageSelect}
            />
          </label>
        )}
      </div>

      {/* Next button */}
      <Button
        type="submit"
        disabled={isSubmitting}
        className="w-auto px-10 rounded-full bg-primary-600 text-white hover:bg-primary-600/90"
      >
        {isSubmitting ? "Saving..." : "Next"}
      </Button>
    </form>
  );
}

async function uploadImages(itemId: string, files: File[]) {
  const csrfToken = getPhoenixCSRFToken();
  const uploaded: Array<{ id: string; position: number; variants: Record<string, string> }> = [];

  for (let i = 0; i < files.length; i++) {
    const formData = new FormData();
    formData.append("file", files[i]);
    formData.append("owner_type", "item");
    formData.append("owner_id", itemId);

    const res = await fetch("/uploads", {
      method: "POST",
      headers: csrfToken ? { "X-CSRF-Token": csrfToken } : {},
      body: formData,
    });

    if (!res.ok) {
      throw new Error(`Failed to upload image ${i + 1}`);
    }

    const data = await res.json();
    uploaded.push({
      id: data.id,
      position: data.position,
      variants: data.variants,
    });
  }

  return uploaded;
}

function findCategoryName(categories: Category[], catId: string, subId: string): string {
  for (const cat of categories) {
    if (subId) {
      const sub = cat.categories.find((s) => s.id === subId);
      if (sub) return sub.name;
    }
    if (cat.id === catId) return cat.name;
  }
  return "";
}
