# Phase 2 Frontend: Wallet, Verification & Blacklist UI

**Date:** 2026-02-20
**Status:** Approved Design
**Dependencies:** Phase 2 backend (UserWallet, UserVerification, SellerBlacklist resources)

## 1. Overview

Build frontend UI for Phase 2 trust and payment features:
- **Wallet UI** - Deposit/withdraw funds for bid commitment
- **Verification UI** - Phone OTP and ID document upload
- **Blacklist UI** - Sellers block problematic bidders
- **Bid Validation** - Enforce requirements with helpful error modals

## 2. Design Decisions

### 2.1 Minimal Pages Approach

**Strategy:** Reuse existing pages instead of creating new ones
- Settings > Payments → Bidder wallet (repurpose)
- Store > Payments → Seller payouts (keep existing)
- Settings > Account → Add verification section
- Store > Listings → Add item analytics with bid history

**Rationale:**
- Faster implementation
- Leverages existing UI patterns
- Clear separation: bidder wallet vs seller payouts
- Contextual blacklist management (view bidders → block)

### 2.2 Verification Strategy

**Hybrid Approach:**
- **Proactive:** Verification section in Account Settings (always visible)
- **Just-in-time:** Inline prompts during bidding if requirements not met

**Rationale:**
- Users can verify ahead of time
- Guided prompts reduce friction when bidding
- Clear error messages with direct action buttons

### 2.3 User Flows

**Wallet Flow:**
1. Navigate to Settings > Payments (or via requirement modal)
2. See balance + transaction history
3. Click "Deposit" → preset amounts or custom
4. Redirect to Paystack → complete payment
5. Webhook updates balance → return to app

**Verification Flow:**
1. Navigate to Settings > Account
2. Enter phone number → click "Send OTP"
3. OTP input expands inline → enter 6 digits
4. Upload ID → drag-drop (desktop) or camera (mobile)
5. Admin reviews ID (24-48 hours)

**Blacklist Flow:**
1. Navigate to Store > Listings → click item
2. View bid history with all bidders
3. Click action menu (⋮) on bidder → "Block from my items"
4. Confirm with optional reason
5. Blocked user cannot bid on seller's items

## 3. Component Architecture

### 3.1 File Structure

```
assets/js/
├── pages/
│   ├── settings/
│   │   ├── account.tsx (existing - add verification section)
│   │   └── payments.tsx (repurpose for bidder wallet)
│   └── store/
│       ├── payments.tsx (existing - keep for seller payouts)
│       └── listings/[id]/analytics.tsx (new - bid history + block)
│
├── features/
│   ├── wallet/
│   │   ├── deposit-dialog.tsx
│   │   ├── withdraw-dialog.tsx
│   │   ├── transaction-history.tsx
│   │   └── balance-card.tsx
│   ├── verification/
│   │   ├── phone-verification.tsx (inline expansion)
│   │   ├── id-upload.tsx (drag-drop + camera)
│   │   └── verification-status.tsx
│   └── bidding/
│       ├── requirement-modal.tsx (error + actions)
│       └── bid-dialog.tsx (existing - add validation)
│
└── hooks/
    └── use-ash-query.ts (existing - use for RPC calls)
```

### 3.2 Backend Actions (Already Implemented)

**UserWallet:**
- `deposit(amount)` → Paystack integration
- `withdraw(amount, bank_details)`
- `check_balance()`

**UserVerification:**
- `request_phone_otp(phone_number)` → Send SMS OTP
- `verify_phone_otp(otp_code)` → Validate and mark verified
- `upload_id_document(file)` → S3 upload
- `resubmit_id_document(file)` → After rejection
- `update_id_verification_status(status, reason)` → Admin action

**SellerBlacklist:**
- `create(seller_id, blocked_user_id, reason)`
- `destroy(id)` → Unblock user
- `read()` → List blocked users

## 4. Detailed UI Specifications

### 4.1 Wallet UI (Settings > Payments)

#### Role Detection
- If user has items listed → show seller payout interface (existing)
- If user only bids → show bidder wallet interface (new)
- If both → tabs: "Wallet" (bidder) | "Payouts" (seller)

#### Balance Card
```
┌─────────────────────────────────┐
│ Wallet Balance                  │
│ ₦5,000.00                       │
│                                 │
│ [Deposit]  [Withdraw]           │
└─────────────────────────────────┘
```

#### Transaction History
- Table: Date | Type | Amount | Balance After
- Types: Deposit, Withdrawal, Purchase, Refund
- Filter: All | Deposits | Withdrawals | Purchases
- Pagination: 20 per page
- Sort: Newest first

#### Deposit Dialog
- **Preset amounts:** ₦1,000 | ₦5,000 | ₦10,000 | Custom
- **Custom input:** Min ₦100, no max
- **Smart suggestions:** Pre-fill when accessed from bid requirement modal
  - Example: "Deposit ₦5,000 to place this bid"
- **Action:** "Deposit" button → opens Paystack payment link
- **After payment:** Webhook updates balance, dialog closes, toast confirmation

#### Withdraw Dialog
- **Amount input:** Max = current balance
- **Bank details form:**
  - Bank name (dropdown)
  - Account number
  - Account name (auto-verify via Paystack)
- **Action:** "Withdraw" button → creates withdrawal request
- **Processing time:** 1-3 business days
- **State:** Show pending withdrawals in transaction history

### 4.2 Verification UI (Settings > Account)

#### Location
Add after address field, before "Quick Sign In" section

#### Phone Verification (Inline Expansion)
```
Phone Number
┌─────────────────────────────────────┐
│ [🇳🇬] 234 [8012345678]              │
│ [Send OTP] or ✓ Verified 19/06/25  │
└─────────────────────────────────────┘

↓ (After clicking "Send OTP")

┌─────────────────────────────────────┐
│ OTP sent to +234801234****          │
│ [______] (6-digit input)             │
│ [Verify]  Resend in 60s              │
└─────────────────────────────────────┘
```

**Flow:**
1. User enters phone → clicks "Send OTP"
2. OTP input field expands inline below
3. Enter 6-digit code → "Verify" button
4. Success → field shows "✓ Verified" + date
5. Rate limit: 1 OTP per 60 seconds (show countdown)

**States:**
- Unverified: Phone input + "Send OTP" button
- OTP sent: Phone input disabled + OTP input + "Verify" button
- Verified: Phone input disabled + green checkmark + date

#### ID Upload (Responsive)
```
Government ID
┌─────────────────────────────────────┐
│ [Drag & drop or click to upload]    │
│  Accepted: JPG, PNG, PDF (max 5MB)  │
│                                      │
│ ↓ (After upload)                    │
│ ✓ drivers-license.jpg                │
│ Status: Pending Review               │
│ Uploaded: 19/06/25                   │
└─────────────────────────────────────┘
```

**Desktop:** Drag-and-drop zone + file picker fallback
**Mobile:** Button triggers camera/gallery picker

**Verification States:**
- **Not uploaded:** Drag-drop zone
- **Pending:** Document name + "⏳ Pending Review" badge + date
- **Approved:** Document name + "✓ Approved" badge + date
- **Rejected:** Document name + "❌ Rejected" badge + reason + "Resubmit" button

**Upload Specs:**
- Formats: JPG, PNG, PDF
- Max size: 5MB
- Validation: Client-side before upload
- Error handling: "File too large" or "Invalid format"

### 4.3 Blacklist UI (Store > Item Analytics)

#### Access Path
Store > Listings → Click row or "View Analytics" action

#### Analytics Page Layout
```
┌─────────────────────────────────────────────┐
│ [← Back to Listings]                        │
│                                             │
│ Samsung Galaxy S24 Ultra                    │
│ Status: Active • Ends in 2d 5h              │
│                                             │
│ ┌─────┬─────┬─────┬─────┐                 │
│ │Views│Watch│ Bids│Price│                 │
│ │ 127 │  12 │   8 │₦450k│                 │
│ └─────┴─────┴─────┴─────┘                 │
│                                             │
│ Bid History                                 │
│ ┌───────────────────────────────────────┐ │
│ │ User          | Amount  | Time   | •  │ │
│ │─────────────────────────────────────  │ │
│ │ @bidder_123   | ₦450,000| 2h ago | ⋮  │ │
│ │ @john_doe     | ₦420,000| 5h ago | ⋮  │ │
│ │ @jane_smith   | ₦400,000| 1d ago | ⋮  │ │
│ └───────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

#### Action Menu (⋮) per Bidder
- View Profile
- **Block from my items** ← blacklist action
- (Future: Message)

#### Block Confirmation Dialog
```
┌─────────────────────────────────────┐
│ Block @bidder_123 from your items? │
│                                     │
│ Reason (optional):                  │
│ [Dropdown: Non-payment / Rude /     │
│  Suspicious / Other]                │
│                                     │
│ [Text area if "Other" selected]    │
│                                     │
│ [@bidder_123 won't be able to bid  │
│  on any of your future items]      │
│                                     │
│ [Cancel]  [Block Bidder]            │
└─────────────────────────────────────┘
```

#### Blocked Bidders Tab
Add tab: "Blocked Bidders" (count badge)
- List of blocked users
- Columns: Username | Reason | Blocked Date | Action
- Unblock action available (trash icon)
- Empty state: "No blocked bidders"

### 4.4 Bid Validation Flow

#### Validation Sequence (Backend)
When user clicks "Place Bid":
1. Auction is active
2. Bidder not blocked by seller
3. Wallet balance meets requirement:
   - <₦50k items: ₦1,000 minimum
   - ≥₦50k items: ₦5,000 minimum
4. Phone verified (always required)
5. ID verified (required for ≥₦50k items only)
6. Bid amount meets increment rules

#### Requirement Modal (on validation failure)

**Example: Multiple Missing Requirements**
```
┌─────────────────────────────────────────┐
│ Requirements to Bid on This Item        │
│                                         │
│ This ₦400,000 item requires:            │
│                                         │
│ ✓ Wallet Balance: ₦5,000 minimum       │
│   Current: ₦2,000 (Need ₦3,000 more)   │
│   → [Deposit ₦3,000 Now]                │
│                                         │
│ ✗ Phone Verification                    │
│   → [Verify Phone Number]               │
│                                         │
│ ✗ ID Verification                       │
│   → [Upload Government ID]              │
│                                         │
│ [Cancel]                                │
└─────────────────────────────────────────┘
```

#### Action Button Behaviors

**[Deposit ₦X Now]:**
- Opens deposit dialog pre-filled with exact amount needed
- After successful deposit → modal auto-closes, retries bid
- On failure → shows error, keeps modal open

**[Verify Phone Number]:**
- Redirects to Settings > Account
- Auto-focuses phone number field
- Toast: "Complete phone verification, then return to bid"

**[Upload Government ID]:**
- Redirects to Settings > Account
- Auto-scrolls to ID upload section
- Toast: "Upload ID for review (24-48hr approval), then bid"

#### Success Flow
All requirements met → Bid confirmation dialog → Submit → Success toast

## 5. Data Flow & State Management

### 5.1 AshTypescript RPC Integration

All backend communication via `useAshQuery` / `useAshMutation` from `@/hooks/use-ash-query`.

#### Wallet Operations
```typescript
// Fetch wallet
const { data: wallet } = useAshQuery({
  resource: "UserWallet",
  action: "read",
  input: { filter: { user_id: currentUser.id } }
});

// Deposit
const depositMutation = useAshMutation({
  resource: "UserWallet",
  action: "deposit",
  onSuccess: (data) => {
    window.location.href = data.payment_url; // Paystack
  },
  onError: (error) => {
    toast.error(error.message);
  }
});

// Withdraw
const withdrawMutation = useAshMutation({
  resource: "UserWallet",
  action: "withdraw",
  onSuccess: () => {
    toast.success("Withdrawal request submitted");
    queryClient.invalidateQueries(["UserWallet"]);
  }
});
```

#### Verification Operations
```typescript
// Request OTP
const requestOtpMutation = useAshMutation({
  resource: "UserVerification",
  action: "request_phone_otp",
  onSuccess: (data) => {
    setOtpSent(true);
    // In test mode, backend returns OTP in response
    if (data.otp_code) setDevOtp(data.otp_code);
    startCountdown(60);
  }
});

// Verify OTP
const verifyOtpMutation = useAshMutation({
  resource: "UserVerification",
  action: "verify_phone_otp",
  onSuccess: () => {
    toast.success("Phone verified!");
    queryClient.invalidateQueries(["User"]);
  },
  onError: (error) => {
    toast.error(error.message); // "Invalid OTP" or "OTP expired"
  }
});

// Upload ID
const uploadIdMutation = useAshMutation({
  resource: "UserVerification",
  action: "upload_id_document",
  onSuccess: () => {
    toast.success("ID submitted for review");
    queryClient.invalidateQueries(["UserVerification"]);
  }
});
```

#### Blacklist Operations
```typescript
// Block bidder
const blockBidderMutation = useAshMutation({
  resource: "SellerBlacklist",
  action: "create",
  onSuccess: () => {
    toast.success("Bidder blocked");
    queryClient.invalidateQueries(["ItemBidHistory"]);
    closeDialog();
  }
});

// Unblock bidder
const unblockMutation = useAshMutation({
  resource: "SellerBlacklist",
  action: "destroy",
  onSuccess: () => {
    toast.success("Bidder unblocked");
    queryClient.invalidateQueries(["SellerBlacklist"]);
  }
});
```

### 5.2 State Management Strategy

**Server State:** TanStack Query (via useAshQuery/Mutation)
- Wallet balance, transactions
- User verification status
- Blacklist records
- Item bid history

**Form State:** React Hook Form + Zod validation
- Deposit/withdraw forms
- Phone OTP input
- ID upload form
- Block bidder form

**UI State:** React useState
- Modal/dialog open state
- OTP countdown timer
- File upload progress
- Inline expansion (OTP field)

### 5.3 Cache Invalidation

**After wallet deposit:**
- Invalidate `["UserWallet"]` query
- Refetch transactions list

**After verification:**
- Invalidate `["User"]` query (includes verification status)
- Update requirement modal state

**After block/unblock:**
- Invalidate `["ItemBidHistory"]` for that item
- Invalidate `["SellerBlacklist"]` list

## 6. Error Handling & Edge Cases

### 6.1 Error States

#### Wallet Errors
- **Insufficient balance for withdrawal:**
  - Message: "Insufficient balance (available: ₦2,000, requested: ₦5,000)"
  - Disable withdraw button if amount > balance
- **Paystack payment failure:**
  - Webhook receives failure → show error toast
  - Provide "Retry Payment" button
- **Network error during deposit:**
  - Retry button with loading state
  - Link to support if persists

#### Verification Errors
- **Invalid OTP:**
  - Error message below input: "Invalid code. Please try again."
  - Keep input focused, clear value
- **OTP expired:**
  - Error message: "OTP expired. Please request a new one."
  - Show "Request New OTP" button
- **Rate limit hit:**
  - Disable "Send OTP" button
  - Show countdown: "Resend in 45s"
- **ID upload too large:**
  - Error: "File must be under 5MB. Try compressing or use a different format."
  - Show current size
- **ID upload wrong format:**
  - Error: "Please upload JPG, PNG, or PDF only"
- **ID rejected by admin:**
  - Show rejection reason in UI
  - "Resubmit" button to upload new document

#### Blacklist Errors
- **Already blocked:**
  - Toast: "This user is already blocked"
  - Don't show block option in menu
- **Can't block self:**
  - Validation prevents this (frontend + backend)
- **Network error:**
  - Toast with retry button
  - Dialog stays open

### 6.2 Edge Cases

#### Wallet
- **Concurrent deposit/withdraw:**
  - Backend handles with transactions (TODO: atomic updates needed)
  - Frontend uses optimistic updates cautiously
- **Paystack webhook delay:**
  - Show "Processing payment..." state
  - Poll wallet balance every 3s for 30s
  - Timeout → "Payment being processed, check back shortly"
- **Withdrawal in progress:**
  - Disable withdraw button
  - Show pending withdrawal in transaction list
  - Status badge: "⏳ Processing (1-3 days)"

#### Verification
- **Phone already verified:**
  - Show verified status, no re-verification UI
  - Only show if user wants to change number
- **ID pending review:**
  - Show "⏳ Pending Review" status
  - Disable upload until reviewed
  - No resubmit button
- **Multiple OTP requests:**
  - Rate limit: 1 per 60s (backend enforced)
  - Frontend shows countdown timer
  - Disable button until timer expires

#### Blacklist
- **Block user with active bid:**
  - Allow block (doesn't cancel existing bids)
  - Prevents future bids only
  - Show warning: "Active bids won't be cancelled"
- **Unblock then re-block:**
  - Works as expected
  - Can change reason on re-block
- **Viewing blocked bidder's profile:**
  - Show "🚫 Blocked" badge on their profile

### 6.3 Loading States

**Button Spinners:**
- "Send OTP" → spinning + disabled
- "Verify" → spinning + disabled
- "Deposit" / "Withdraw" → spinning + disabled
- "Block Bidder" → spinning + disabled

**Skeleton Loaders:**
- Wallet balance card (initial load)
- Transaction history table
- Bid history table

**Optimistic Updates:**
- Expand OTP field immediately (don't wait for API)
- Show uploaded file preview before server confirmation
- Update UI on block action before API confirms

### 6.4 Accessibility

**ARIA Labels:**
- All buttons have descriptive labels
- Form inputs have associated labels
- Error messages linked to inputs via `aria-describedby`

**Keyboard Navigation:**
- Tab through all interactive elements
- Enter to submit forms
- Escape to close modals/dialogs
- Arrow keys in dropdowns

**Screen Reader Support:**
- Announce OTP sent: "OTP sent to your phone"
- Announce verification success: "Phone number verified"
- Announce errors: "Error: Invalid OTP code"

**Focus Management:**
- Auto-focus OTP input after sending
- Return focus to trigger after modal close
- Focus first error field on validation failure

## 7. Implementation Phases

### Phase 1: Wallet UI (Days 1-3)
- Repurpose Settings > Payments for bidders
- Balance card + transaction history
- Deposit dialog with Paystack integration
- Withdraw dialog with bank details form

### Phase 2: Verification UI (Days 4-6)
- Phone OTP inline expansion in Account Settings
- ID upload with drag-drop/camera
- Verification status display
- Admin review flow (backend already exists)

### Phase 3: Blacklist UI (Days 7-8)
- Store > Listings > Item > Analytics page
- Bid history table
- Block action in bidder menu
- Blocked bidders list

### Phase 4: Bid Validation (Days 9-10)
- Requirement modal with action buttons
- Integration with existing bid dialog
- Error handling for all validation failures
- Smart deposit suggestions

### Phase 5: Testing & Polish (Days 11-12)
- Unit tests for all components
- Integration tests for flows
- Mobile responsiveness
- Accessibility audit

## 8. Success Metrics

**Wallet Adoption:**
- % of bidders with wallet balance >₦0
- Average deposit amount
- Deposit → bid conversion rate

**Verification Completion:**
- % of bidders with phone verified
- % of bidders with ID verified
- Time to verify (phone vs ID)

**Blacklist Usage:**
- % of sellers using blacklist
- Average blocks per seller
- Repeat offense rate (blocked users bidding on other items)

**User Experience:**
- Bid validation modal → completion rate
- Requirement modal → action click rate
- Time from requirement prompt to completion

## 9. Future Enhancements

**V2 Features:**
- Auto-deposit from wallet on bid win
- Wallet balance widget in user menu dropdown
- Push notifications for verification status
- Batch blacklist management
- Reputation scores based on verification + history

**Mobile App:**
- Native camera integration for ID upload
- SMS OTP auto-fill
- Biometric verification

**Analytics:**
- Seller dashboard: bid patterns, block trends
- Platform-wide: verification completion rates
- Payment gateway: success/failure metrics
