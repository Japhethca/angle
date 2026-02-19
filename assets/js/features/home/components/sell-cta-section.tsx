import { AuthLink } from "@/features/auth";
import { Button } from "@/components/ui/button";
import { ArrowRight } from "lucide-react";
import { Section } from "@/components/layouts";

export function SellCtaSection() {
  return (
    <Section fullBleed background="accent" className="py-10 lg:py-16">
      <div className="mx-auto flex max-w-5xl flex-col items-center gap-8 lg:flex-row lg:gap-16">
        {/* Copy side */}
        <div className="flex-1 text-center lg:text-left">
          <h2 className="font-heading text-2xl font-semibold text-content lg:text-[32px]">
            Start Selling on Angle
          </h2>
          <p className="mt-3 text-base text-content-secondary lg:text-lg">
            Turn your unused items into cash. List your items, set a starting
            price, and let bidders compete. It&apos;s free to get started.
          </p>
          <Button
            size="lg"
            className="mt-6 rounded-full bg-primary-600 px-8 text-white hover:bg-primary-600/90"
            asChild
          >
            <AuthLink href="/store/listings/new" auth>
              List an Item
              <ArrowRight className="ml-2 size-4" />
            </AuthLink>
          </Button>
        </div>

        {/* Image/illustration side */}
        <div className="flex flex-1 items-center justify-center">
          <div className="flex aspect-[4/3] w-full max-w-md items-center justify-center rounded-2xl bg-gradient-to-br from-primary-100 to-primary-200 dark:from-primary-900/30 dark:to-primary-800/20">
            <div className="text-center">
              <span className="text-6xl">🏷️</span>
              <p className="mt-2 text-sm text-primary-700 dark:text-primary-400">
                List. Auction. Earn.
              </p>
            </div>
          </div>
        </div>
      </div>
    </Section>
  );
}
