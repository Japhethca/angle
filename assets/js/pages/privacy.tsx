import { Head } from "@inertiajs/react";
import { ArrowLeft } from "lucide-react";

export default function Privacy() {
  return (
    <>
      <Head title="Privacy Policy" />
      <div className="mx-auto max-w-3xl px-4 py-8 lg:py-12">
        <button
          onClick={() => window.history.back()}
          className="mb-6 inline-flex items-center gap-2 text-sm text-content-tertiary hover:text-content"
        >
          <ArrowLeft className="size-4" />
          Back
        </button>

        <h1 className="mb-6 text-2xl font-bold text-content">Privacy Policy</h1>
        <p className="mb-4 text-sm text-content-tertiary">
          Last updated: February 15, 2026
        </p>

        <div className="prose prose-sm max-w-none text-content-secondary">
          <h2 className="text-lg font-semibold text-content">1. Information We Collect</h2>
          <p>
            We collect information you provide directly, such as your name, email
            address, phone number, and payment information when you create an account
            or use our services.
          </p>

          <h2 className="mt-6 text-lg font-semibold text-content">2. How We Use Your Information</h2>
          <p>
            We use your information to operate and improve Angle, process transactions,
            communicate with you, and ensure the security of our platform.
          </p>

          <h2 className="mt-6 text-lg font-semibold text-content">3. Information Sharing</h2>
          <p>
            We do not sell your personal information. We may share your information
            with service providers who help us operate the platform, or as required
            by law.
          </p>

          <h2 className="mt-6 text-lg font-semibold text-content">4. Data Security</h2>
          <p>
            We implement appropriate technical and organizational measures to protect
            your personal data against unauthorized access, alteration, or destruction.
          </p>

          <h2 className="mt-6 text-lg font-semibold text-content">5. Your Rights</h2>
          <p>
            You have the right to access, correct, or delete your personal data. You
            may also request a copy of the data we hold about you by contacting our
            support team.
          </p>

          <h2 className="mt-6 text-lg font-semibold text-content">6. Contact</h2>
          <p>
            If you have questions about this Privacy Policy, please contact us at
            privacy@angle.com.
          </p>
        </div>
      </div>
    </>
  );
}
