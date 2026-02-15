# Legal Settings Page Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a Legal section to Settings with collapsible Terms of Service and Privacy Policy accordions, plus standalone `/terms` and `/privacy` pages.

**Architecture:** Static React pages using the existing `SettingsLayout` and shadcn `Accordion` components. No backend data — controller actions just render Inertia pages. Standalone legal pages use the default app layout (navbar).

**Tech Stack:** React, Inertia.js, shadcn Accordion (Radix), Tailwind CSS, Phoenix controllers

**Design doc:** `docs/plans/2026-02-15-legal-settings-design.md`

**Figma:** Desktop `454-6223`, Mobile `636-6714`

---

### Task 1: Backend — Add routes and controller actions

**Files:**
- Modify: `lib/angle_web/controllers/settings_controller.ex`
- Modify: `lib/angle_web/router.ex`

**Step 1: Add `legal/2` action to SettingsController**

In `lib/angle_web/controllers/settings_controller.ex`, add after the `preferences` action (line 48):

```elixir
def legal(conn, _params) do
  conn
  |> render_inertia("settings/legal")
end
```

**Step 2: Add `legal` route to router**

In `lib/angle_web/router.ex`, inside the protected routes scope (after line 117):

```elixir
get "/settings/legal", SettingsController, :legal
```

**Step 3: Add `/terms` and `/privacy` public routes**

In `lib/angle_web/router.ex`, inside the public routes scope (after line 73, before the `end` on line 76):

```elixir
get "/terms", PageController, :terms
get "/privacy", PageController, :privacy
```

**Step 4: Add `terms/2` and `privacy/2` actions to PageController**

In `lib/angle_web/controllers/page_controller.ex`, add:

```elixir
def terms(conn, _params) do
  conn |> render_inertia(:terms)
end

def privacy(conn, _params) do
  conn |> render_inertia(:privacy)
end
```

**Step 5: Verify the server compiles**

Run: `mix compile --warnings-as-errors`
Expected: Compilation succeeds

**Step 6: Commit**

```
feat: add legal settings and public legal page routes
```

---

### Task 2: Legal settings page — Accordion UI

**Files:**
- Create: `assets/js/features/settings/components/legal-content.tsx`
- Create: `assets/js/pages/settings/legal.tsx`
- Modify: `assets/js/features/settings/index.ts`

**Step 1: Create LegalContent component**

Create `assets/js/features/settings/components/legal-content.tsx`:

```tsx
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
            <p className="text-sm font-semibold text-content">Privacy Service</p>
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
```

**Step 2: Create the legal settings page**

Create `assets/js/pages/settings/legal.tsx`:

```tsx
import { Head } from "@inertiajs/react";
import { SettingsLayout, LegalContent } from "@/features/settings";

export default function SettingsLegal() {
  return (
    <>
      <Head title="Legal" />
      <SettingsLayout title="Legal">
        <LegalContent />
      </SettingsLayout>
    </>
  );
}
```

**Step 3: Export LegalContent from feature index**

In `assets/js/features/settings/index.ts`, add the export:

```typescript
export { LegalContent } from "./components/legal-content";
```

**Step 4: Verify page renders**

Open `http://localhost:4111/settings/legal` in browser — should show the accordion with two items.

**Step 5: Commit**

```
feat: add legal settings page with accordion UI
```

---

### Task 3: Enable Legal in sidebar and mobile menu

**Files:**
- Modify: `assets/js/features/settings/components/settings-layout.tsx`
- Modify: `assets/js/pages/settings/index.tsx`

**Step 1: Enable Legal in desktop sidebar**

In `assets/js/features/settings/components/settings-layout.tsx`, change line 25 from:

```typescript
{ label: "Legal", href: "#", disabled: true, icon: Scale },
```

to:

```typescript
{ label: "Legal", href: "/settings/legal", icon: Scale },
```

**Step 2: Enable Legal in mobile settings index**

In `assets/js/pages/settings/index.tsx`, change the Legal menu item (line 17) from:

```typescript
{ label: "Legal", icon: Scale, disabled: true },
```

to:

```typescript
{ label: "Legal", icon: Scale, href: "/settings/legal" },
```

**Step 3: Verify navigation works**

- Desktop: click "Legal" in sidebar — should navigate and show active state
- Mobile: click "Legal" in menu — should navigate to legal page with back arrow

**Step 4: Commit**

```
feat: enable legal navigation in settings sidebar and mobile menu
```

---

### Task 4: Standalone Terms of Service page

**Files:**
- Create: `assets/js/pages/terms.tsx`

**Step 1: Create terms page**

Create `assets/js/pages/terms.tsx`:

```tsx
import { Head, Link } from "@inertiajs/react";
import { ArrowLeft } from "lucide-react";

export default function Terms() {
  return (
    <>
      <Head title="Terms of Service" />
      <div className="mx-auto max-w-3xl px-4 py-8 lg:py-12">
        <Link
          href="/settings/legal"
          className="mb-6 inline-flex items-center gap-2 text-sm text-content-tertiary hover:text-content"
        >
          <ArrowLeft className="size-4" />
          Back to Legal
        </Link>

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
```

**Step 2: Verify page renders**

Open `http://localhost:4111/terms` — should show the terms page.

**Step 3: Commit**

```
feat: add standalone terms of service page
```

---

### Task 5: Standalone Privacy Policy page

**Files:**
- Create: `assets/js/pages/privacy.tsx`

**Step 1: Create privacy page**

Create `assets/js/pages/privacy.tsx`:

```tsx
import { Head, Link } from "@inertiajs/react";
import { ArrowLeft } from "lucide-react";

export default function Privacy() {
  return (
    <>
      <Head title="Privacy Policy" />
      <div className="mx-auto max-w-3xl px-4 py-8 lg:py-12">
        <Link
          href="/settings/legal"
          className="mb-6 inline-flex items-center gap-2 text-sm text-content-tertiary hover:text-content"
        >
          <ArrowLeft className="size-4" />
          Back to Legal
        </Link>

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
```

**Step 2: Verify page renders**

Open `http://localhost:4111/privacy` — should show the privacy page.

**Step 3: Commit**

```
feat: add standalone privacy policy page
```

---

### Task 6: Figma comparison and polish

**Step 1: Take browser screenshots of `/settings/legal` (desktop and mobile)**

Compare with Figma nodes `454-6223` (desktop) and `636-6714` (mobile).

**Step 2: Fix any discrepancies**

Check accordion styling, spacing, typography, and chevron behavior match the designs.

**Step 3: Commit any fixes**

```
fix: align legal page styling with Figma designs
```
