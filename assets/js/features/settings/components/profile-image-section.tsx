import { useState } from "react";
import { User } from "lucide-react";
import { ImageUploader } from "@/components/image-upload";
import { imageUrl, type ImageData } from "@/lib/image-url";

interface ProfileImageSectionProps {
  userId: string;
  avatarImages: ImageData[];
}

export function ProfileImageSection({
  userId,
  avatarImages: initialImages,
}: ProfileImageSectionProps) {
  const [images, setImages] = useState<ImageData[]>(initialImages);
  const currentAvatar = images.length > 0 ? images[0] : null;

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-4">
        {/* Avatar preview */}
        <div className="flex size-16 shrink-0 items-center justify-center overflow-hidden rounded-full bg-surface-emphasis lg:size-20">
          {currentAvatar ? (
            <img
              src={imageUrl(currentAvatar, "medium")}
              alt="Profile avatar"
              className="size-full object-cover"
            />
          ) : (
            <User className="size-8 text-content-tertiary lg:size-10" />
          )}
        </div>
        <div>
          <p className="mb-2 text-sm font-semibold text-content">
            Profile Image
          </p>
          <p className="text-xs text-content-tertiary">
            JPEG, PNG, or WebP up to 10MB
          </p>
        </div>
      </div>

      {/* Upload control */}
      <ImageUploader
        ownerType="user_avatar"
        ownerId={userId}
        images={images}
        onImagesChange={setImages}
        multiple={false}
      />
    </div>
  );
}
