import { Search, Gavel, Trophy } from "lucide-react";
import { Section } from "@/components/layouts";

const steps = [
  {
    icon: Search,
    title: "Find Items",
    description: "Browse categories or search for items you love",
  },
  {
    icon: Gavel,
    title: "Place Your Bid",
    description: "Set your price and compete with other bidders",
  },
  {
    icon: Trophy,
    title: "Win & Own",
    description: "Highest bid wins when the auction ends",
  },
];

export function HowItWorksSection() {
  return (
    <Section fullBleed background="muted" className="py-10 lg:py-12">
      <h2 className="mb-8 text-center font-heading text-2xl font-semibold text-content lg:text-[32px]">
        How It Works
      </h2>
      <div className="mx-auto grid max-w-3xl grid-cols-1 gap-8 sm:grid-cols-3">
        {steps.map((step, index) => (
          <div key={index} className="flex flex-col items-center text-center">
            <div className="mb-4 flex size-14 items-center justify-center rounded-2xl bg-primary-100 dark:bg-primary-900/30">
              <step.icon className="size-7 text-primary-600" />
            </div>
            <h3 className="text-base font-semibold text-content">{step.title}</h3>
            <p className="mt-1 text-sm text-content-secondary">{step.description}</p>
          </div>
        ))}
      </div>
    </Section>
  );
}
