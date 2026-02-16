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
}

interface StoreProfileProps {
  store_profile: StoreProfileData | null;
  category_summary: CategorySummary[];
  user: UserData;
}

export default function StoreProfile({
  store_profile: storeProfile,
  category_summary: categorySummary = [],
  user,
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
          />
          <ProfileDetails
            user={user}
            storeProfile={storeProfile}
            categorySummary={categorySummary}
          />
          <ReviewsSection />
        </div>
      </StoreLayout>
    </>
  );
}
