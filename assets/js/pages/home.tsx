import type { HomepageItemCard, HomepageCategory } from "@/ash_rpc";
import { useAuth } from "@/features/auth";
import {
  FeaturedItemCarousel,
  GuestHero,
  HowItWorksSection,
  SearchSection,
  EndingSoonSection,
  RecommendedSection,
  TrustStatsSection,
  HotNowSection,
  SellCtaSection,
  BrowseCategoriesSection,
} from "@/features/home";

interface HomeProps {
  featured_items: HomepageItemCard;
  recommended_items: HomepageItemCard;
  ending_soon_items: HomepageItemCard;
  hot_items: HomepageItemCard;
  categories: HomepageCategory;
  watchlisted_map: Record<string, string>;
}

export default function Home({
  featured_items = [],
  recommended_items = [],
  ending_soon_items = [],
  hot_items = [],
  categories = [],
  watchlisted_map = {},
}: HomeProps) {
  const { authenticated } = useAuth();

  return (
    <div>
      {authenticated ? (
        <FeaturedItemCarousel items={featured_items} watchlistedMap={watchlisted_map} />
      ) : (
        <GuestHero />
      )}
      <HowItWorksSection />
      <SearchSection categories={categories} />
      <EndingSoonSection initialItems={ending_soon_items} watchlistedMap={watchlisted_map} />
      <RecommendedSection items={recommended_items} watchlistedMap={watchlisted_map} />
      <TrustStatsSection />
      <HotNowSection items={hot_items} watchlistedMap={watchlisted_map} />
      <SellCtaSection />
      <BrowseCategoriesSection categories={categories} />
    </div>
  );
}
