# Phase 2 Implementation Gaps

## Critical Issues Identified

### 1. Wallet Architecture Misalignment ⚠️ **CRITICAL**

**Expected**: Paystack subaccount integration
**Current**: Basic `user_wallets` table with manual balance tracking

**Impact**:
- No real payment processing integration
- Manual balance management (not production-ready)
- Missing Paystack split payment functionality
- No automated settlement to sellers

**Required Fix**:
- Integrate Paystack Subaccounts API
- Create subaccount when user becomes a seller
- Use subaccounts for:
  - Receiving payments for items sold
  - Automatic settlement to seller's bank account
  - Split payments (platform commission)
- Keep wallet table for tracking/display only (not source of truth)

**Files to Modify**:
- `lib/angle/payments/user_wallet.ex` - Add Paystack subaccount_code field
- `lib/angle/payments/paystack_client.ex` - Implement subaccount operations
- Backend deposit/withdrawal logic - Integrate with Paystack APIs
- Frontend wallet components - Update UX for Paystack flow

**Effort**: High (3-4 hours)

---

### 2. Phone Verification UX Issue ⚠️ **IMPORTANT**

**Expected**: Use existing phone number from user profile
**Current**: Asks user to input phone number again

**Impact**:
- Confusing UX (why ask for what we already have?)
- Potential data inconsistency

**Required Fix**:
- Auto-populate phone number from `user.phone_number`
- If user has no phone number, allow input + save to profile
- Update verification record to use user's phone number

**Files to Modify**:
- `assets/js/features/verification/phone-verification.tsx` - Remove phone input, use prop
- `assets/js/pages/settings/account.tsx` - Pass user.phone_number to component
- `lib/angle_web/controllers/settings_controller.ex` - Include phone in user data

**Effort**: Low (30 minutes)

---

### 3. Missing Analytics Menu Item ⚠️ **IMPORTANT**

**Expected**: Analytics option in item dropdown menu
**Current**: Only Share, Edit (drafts), Delete

**Impact**:
- Analytics page exists but not discoverable
- Users can't access bid history and blacklist management

**Required Fix**:
- Add "Analytics" menu item to `ListingActionsMenu`
- Link to `/store/listings/{id}/analytics`
- Add BarChart icon from lucide-react

**Files to Modify**:
- `assets/js/features/store-dashboard/components/listing-actions-menu.tsx`

**Effort**: Trivial (10 minutes)

---

## Priority Order

1. **Fix #3** (Analytics menu) - Quick win, unblocks user testing
2. **Fix #2** (Phone UX) - Quick, improves user experience
3. **Fix #1** (Paystack integration) - Critical but requires significant work

## Testing Checklist

After fixes:
- [ ] Analytics accessible from listings dropdown ✓
- [ ] Phone verification uses existing phone number ✓
- [ ] Paystack subaccount created when user becomes seller
- [ ] Deposit flow initiates Paystack transaction
- [ ] Withdrawal flow processes from subaccount balance
- [ ] Platform commission handled via split payments
