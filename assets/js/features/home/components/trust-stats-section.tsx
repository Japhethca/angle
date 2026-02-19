import { Package, Gavel, Users, Trophy } from "lucide-react";
import { Section } from "@/components/layouts";

const stats = [
  { icon: Package, value: "1,200+", label: "Items Listed" },
  { icon: Gavel, value: "5,000+", label: "Bids Placed" },
  { icon: Users, value: "800+", label: "Active Bidders" },
  { icon: Trophy, value: "350+", label: "Auctions Won" },
];

export function TrustStatsSection() {
  return (
    <Section fullBleed background="dark" className="py-10 lg:py-12">
      <div className="mx-auto grid max-w-4xl grid-cols-2 gap-8 lg:grid-cols-4">
        {stats.map((stat) => (
          <div key={stat.label} className="flex flex-col items-center text-center">
            <stat.icon className="mb-2 size-6 text-primary-400" />
            <span className="font-heading text-2xl font-bold text-white lg:text-3xl">
              {stat.value}
            </span>
            <span className="mt-1 text-sm text-white/80">{stat.label}</span>
          </div>
        ))}
      </div>
    </Section>
  );
}
