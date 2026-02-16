import { MapPin, Phone, MessageCircle } from "lucide-react";

interface CategorySummary {
  id: string;
  name: string;
  slug: string;
  count: number;
}

interface StoreProfileData {
  id: string;
  storeName: string;
  contactPhone: string | null;
  whatsappLink: string | null;
  location: string | null;
  address: string | null;
  deliveryPreference: string | null;
}

interface UserData {
  id: string;
  email: string;
  fullName: string | null;
  username: string | null;
  phoneNumber: string | null;
  location: string | null;
  createdAt: string | null;
}

interface ProfileDetailsProps {
  user: UserData;
  storeProfile: StoreProfileData | null;
  categorySummary: CategorySummary[];
}

function formatJoinDate(dateStr: string | null | undefined): string {
  if (!dateStr) return "--";
  const date = new Date(dateStr);
  return date.toLocaleDateString("en-US", {
    month: "long",
    year: "numeric",
  });
}

export function ProfileDetails({ user, storeProfile, categorySummary }: ProfileDetailsProps) {
  const location = storeProfile?.location || user.location;
  const phone = storeProfile?.contactPhone || user.phoneNumber;
  const whatsapp = storeProfile?.whatsappLink;

  return (
    <div className="rounded-xl border border-surface-muted bg-surface p-6">
      <h3 className="text-base font-semibold text-content">Details</h3>

      <div className="mt-4 space-y-3">
        {/* Date joined */}
        <p className="text-sm text-content-placeholder">
          Joined {formatJoinDate(user.createdAt)}
        </p>

        {/* Contact info */}
        <div className="flex flex-wrap items-center gap-x-4 gap-y-2">
          {location && (
            <span className="flex items-center gap-1.5 text-sm text-content-tertiary">
              <MapPin className="size-4 text-content-placeholder" />
              {location}
            </span>
          )}
          {phone && (
            <span className="flex items-center gap-1.5 text-sm text-content-tertiary">
              <Phone className="size-4 text-content-placeholder" />
              {phone}
            </span>
          )}
          {whatsapp && (
            <span className="flex items-center gap-1.5 text-sm text-content-tertiary">
              <MessageCircle className="size-4 text-content-placeholder" />
              {whatsapp}
            </span>
          )}
        </div>

        {/* Category badges */}
        {categorySummary.length > 0 && (
          <div className="flex flex-wrap gap-2 pt-1">
            {categorySummary.map((cat) => (
              <span
                key={cat.id}
                className="rounded-lg border border-surface-muted bg-surface-secondary px-3 py-1 text-xs text-content-secondary"
              >
                {cat.name}{" "}
                <span className="text-content-placeholder">({cat.count})</span>
              </span>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
