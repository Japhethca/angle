import { Link } from "@inertiajs/react";
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";

export function LegalContent() {
  return (
    <Accordion type="single" collapsible className="w-full">
      <AccordionItem value="terms">
        <AccordionTrigger className="hover:no-underline">
          <div>
            <p className="text-sm font-semibold text-content">Terms of Service</p>
            <p className="text-sm font-normal text-content-tertiary">
              Understand the rules for using Angle.
            </p>
          </div>
        </AccordionTrigger>
        <AccordionContent>
          <p className="mb-3 text-sm text-content-secondary">
            Our Terms of Service outline the rules and guidelines for using the Angle
            platform, including account responsibilities, bidding policies, and
            acceptable use.
          </p>
          <Link
            href="/terms"
            className="text-sm font-medium text-primary-600 hover:underline"
          >
            Read full Terms of Service
          </Link>
        </AccordionContent>
      </AccordionItem>

      <AccordionItem value="privacy">
        <AccordionTrigger className="hover:no-underline">
          <div>
            <p className="text-sm font-semibold text-content">Privacy Policy</p>
            <p className="text-sm font-normal text-content-tertiary">
              See how we collect, use, and protect your data.
            </p>
          </div>
        </AccordionTrigger>
        <AccordionContent>
          <p className="mb-3 text-sm text-content-secondary">
            Our Privacy Policy explains what personal data we collect, how we use it,
            and the measures we take to keep your information secure.
          </p>
          <Link
            href="/privacy"
            className="text-sm font-medium text-primary-600 hover:underline"
          >
            Read full Privacy Policy
          </Link>
        </AccordionContent>
      </AccordionItem>
    </Accordion>
  );
}
