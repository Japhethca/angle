import type { HomepageItemCard, HomepageCategory } from "@/ash_rpc";
import { FeaturedItemCarousel } from "@/components/home/featured-item-carousel";
import { RecommendedSection } from "@/components/home/recommended-section";
import { EndingSoonSection } from "@/components/home/ending-soon-section";
import { HotNowSection } from "@/components/home/hot-now-section";
import { BrowseCategoriesSection } from "@/components/home/browse-categories-section";

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
