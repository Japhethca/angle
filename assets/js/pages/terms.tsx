import { Head } from "@inertiajs/react";
import { ArrowLeft } from "lucide-react";

export default function Terms() {
  return (
    <>
      <Head title="Terms of Service" />
      <div className="mx-auto max-w-3xl px-4 py-8 lg:py-12">
        <button
          onClick={() => window.history.back()}
          className="mb-6 inline-flex items-center gap-2 text-sm text-content-tertiary hover:text-content"
        >
          <ArrowLeft className="size-4" />
          Back
        </button>

        <h1 className="mb-6 text-2xl font-bold text-content">Terms of Service</h1>
        <p className="mb-4 text-sm text-content-tertiary">
          Last updated: February 15, 2026
        </p>

        <div className="prose prose-sm max-w-none text-content-secondary">
          <h2 className="text-lg font-semibold text-content">1. Acceptance of Terms</h2>
          <p>
            By accessing or using Angle, you agree to be bound by these Terms of
            Service. If you do not agree to these terms, please do not use our platform.
          </p>

          <h2 className="mt-6 text-lg font-semibold text-content">2. Use of the Platform</h2>
          <p>
            Angle provides an online auction platform where users can list items for
            auction and place bids. You must be at least 18 years old and have a valid
            account to participate in auctions.
          </p>

          <h2 className="mt-6 text-lg font-semibold text-content">3. Account Responsibilities</h2>
          <p>
            You are responsible for maintaining the security of your account credentials
            and for all activities that occur under your account. You agree to notify
            Angle immediately of any unauthorized use.
          </p>

          <h2 className="mt-6 text-lg font-semibold text-content">4. Bidding Policies</h2>
          <p>
            All bids placed on Angle are binding. By placing a bid, you agree to
            purchase the item at the bid price if you are the winning bidder. Bid
            manipulation or shill bidding is strictly prohibited.
          </p>

          <h2 className="mt-6 text-lg font-semibold text-content">5. Limitation of Liability</h2>
          <p>
            Angle is not liable for any damages arising from your use of the platform,
            including but not limited to direct, indirect, incidental, or consequential
            damages.
          </p>

          <h2 className="mt-6 text-lg font-semibold text-content">6. Contact</h2>
          <p>
            If you have questions about these Terms, please contact us at
            support@angle.com.
          </p>
        </div>
      </div>
    </>
  );
}
