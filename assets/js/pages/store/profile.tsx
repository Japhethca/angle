import { Head } from "@inertiajs/react";
import {
  StoreLayout,
  ProfileHeader,
  ProfileDetails,
  ReviewsSection,
} from "@/features/store-dashboard";

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
  avgRating?: number | null;
  reviewCount?: number;
}

interface StoreProfileProps {
  store_profile: StoreProfileData | null;
  category_summary: CategorySummary[];
  user: UserData;
  reviews?: Array<{
    id: string;
    rating: number;
    comment: string | null;
    insertedAt: string;
    reviewer?: { id: string; username: string | null; fullName: string | null };
  }>;
}

export default function StoreProfile({
  store_profile: storeProfile,
  category_summary: categorySummary = [],
  user,
  reviews,
}: StoreProfileProps) {
  const storeName = storeProfile?.storeName || user?.fullName || "My Store";

  return (
    <>
      <Head title="Store - Profile" />
      <StoreLayout title="Store Profile">
        <div className="space-y-6">
          <ProfileHeader
            storeName={storeName}
            username={user?.username || null}
            avgRating={user?.avgRating}
            reviewCount={user?.reviewCount}
          />
          <ProfileDetails
            user={user}
            storeProfile={storeProfile}
            categorySummary={categorySummary}
          />
          <ReviewsSection reviews={reviews || []} />
        </div>
      </StoreLayout>
    </>
  );
}
