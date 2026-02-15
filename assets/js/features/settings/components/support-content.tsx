import { Link } from "@inertiajs/react";
import { ExternalLink, Mail, MapPin, Phone } from "lucide-react";
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";

export function SupportContent() {
  return (
    <div className="space-y-6">
      {/* Section 1: Help Center */}
      <Accordion type="single" collapsible className="w-full">
        <AccordionItem value="help-center">
          <AccordionTrigger className="hover:no-underline">
            <div>
              <p className="text-sm font-semibold text-content">Help Center</p>
              <p className="text-sm font-normal text-content-tertiary">
                Find answers to common questions and guides.
              </p>
            </div>
          </AccordionTrigger>
          <AccordionContent>
            <p className="mb-3 text-sm text-content-secondary">
              Browse our comprehensive help center for guides, tutorials, and
              answers to frequently asked questions.
            </p>
            <Link
              href="#"
              className="text-sm font-medium text-primary-600 hover:underline"
            >
              Visit Help Center
            </Link>
          </AccordionContent>
        </AccordionItem>
      </Accordion>

      {/* Section 2: Contact Support */}
      <div>
        <p className="mb-4 text-sm font-semibold text-content">
          Contact Support
        </p>
        <div className="rounded-lg border border-subtle p-4">
          <div className="space-y-4">
            <div className="flex flex-row gap-3">
              <Mail className="size-5 text-content-tertiary" />
              <div>
                <p className="text-sm font-medium text-content">Email</p>
                <a
                  href="mailto:support@angle.com"
                  className="text-sm text-primary-600"
                >
                  support@angle.com
                </a>
              </div>
            </div>

            <div className="flex flex-row gap-3">
              <Phone className="size-5 text-content-tertiary" />
              <div>
                <p className="text-sm font-medium text-content">Phone</p>
                <a href="tel:+23481796988" className="block text-sm text-primary-600">
                  +23481796988
                </a>
                <a href="tel:+2348177417875" className="block text-sm text-primary-600">
                  +2348177417875
                </a>
              </div>
            </div>

            <div className="flex flex-row gap-3">
              <MapPin className="size-5 text-content-tertiary" />
              <div>
                <p className="text-sm font-medium text-content">Address</p>
                <p className="text-sm text-content-secondary">
                  1A, Alana drive, Lagos
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Section 3: Report An Issue */}
      <a
        href="#"
        className="inline-flex items-center gap-1 text-sm font-medium text-primary-600"
      >
        Report An Issue
        <ExternalLink className="size-4" />
      </a>
    </div>
  );
}
