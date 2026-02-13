import type { HomepageItemCard, HomepageCategory } from "@/ash_rpc";
import {
  FeaturedItemCarousel,
  RecommendedSection,
  EndingSoonSection,
  HotNowSection,
  BrowseCategoriesSection,
} from "@/features/home";

interface HomeProps {
  featured_items: HomepageItemCard;
  recommended_items: HomepageItemCard;
  ending_soon_items: HomepageItemCard;
  hot_items: HomepageItemCard;
  categories: HomepageCategory;
}

export default function Home({
  featured_items = [],
  recommended_items = [],
  ending_soon_items = [],
  hot_items = [],
  categories = [],
}: HomeProps) {
  return (
    <div>
      <FeaturedItemCarousel items={featured_items} />
      <RecommendedSection items={recommended_items} />
      <EndingSoonSection initialItems={ending_soon_items} />
      <HotNowSection items={hot_items} />
      <BrowseCategoriesSection categories={categories} />
    </div>
  );
}
