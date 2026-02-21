# Core Bidding System - Design Document

**Date:** 2026-02-19
**Status:** Approved
**Implementation Approach:** Phased MVP (3 phases over 16 weeks)

---

## Executive Summary

This document outlines the design for a **robust, end-to-end bidding system** for the Angle auction platform, optimized for the Nigerian market. The system supports **hybrid auctions** (auction + buy now), **tiered verification**, **wallet-based commitments**, and **payment escrow** for high-value items.

**Key Features:**
- Hybrid auction model (auction + buy now)
- Wallet-based commitment system (₦1k for <₦50k, ₦5k for ≥₦50k)
- Tiered verification (phone for low-value, phone+ID for high-value)
- Split payments (<₦50k) and escrow (≥₦50k)
- Reserve pricing with transparency
- Soft close with 2 extensions (anti-sniping)
- Private auctions (link-based access)
- Public Q&A system
- Real-time bidding updates

**Monetization:** Commission-based (8% <₦50k, 6% ₦50k-₦200k, 5% ₦200k+)

---

## Table of Contents

1. [Business Requirements](#1-business-requirements)
2. [System Architecture](#2-system-architecture)
3. [Phase 1: Core Auction Engine](#3-phase-1-core-auction-engine-weeks-1-6)
4. [Phase 2: Payment & Trust](#4-phase-2-payment--trust-weeks-7-11)
5. [Phase 3: Advanced Features](#5-phase-3-advanced-features-weeks-12-16)
6. [Data Models](#6-data-models--schema-changes)
7. [Error Handling](#7-error-handling--edge-cases)
8. [Testing Strategy](#8-testing-strategy)
9. [Deployment & Operations](#9-deployment--operations)
10. [Future Enhancements](#10-future-enhancements-phase-4)

---

## 1. Business Requirements

### 1.1 Core Questions Addressed

**Who can bid?**
- Any verified user with minimum wallet balance
- <₦50k items: Phone verification + ₦1,000 wallet
- ≥₦50k items: Phone + ID verification + ₦5,000 wallet

**Can sellers control who bids?**
- Yes: Blacklist functionality (block specific users)
- No: No whitelist/pre-approval (keeps platform open)

**Trust & Security:**
- Wallet commitment signals serious bidders
- Escrow for high-value items (≥₦50k)
- Manual review for ID verification
- Reputation system (non-payment tracking)

**Communication:**
- Public Q&A (transparent, one question helps all buyers)
- No private messaging (Phase 1-3)

**Auction Controls:**
- Sellers can set reserve price (visible indicator, not amount)
- 2-hour override window to reject winner
- Auction can be cancelled if reserve not met

**Buy Now:**
- Hybrid model: auction + optional buy now price
- Buy Now ends auction immediately (first to click wins)

### 1.2 Target Market: Nigeria/Africa

**Design Decisions for Nigerian Market:**
- Commission-based (not listing fees) - aligned with "pay when you succeed"
- Lower than Jumia/Konga (5-10% vs 15-20%)
- Wallet system familiar (like Jumia Pay, betting platforms)
- WhatsApp sharing for private auctions
- Mobile-first UX
- Transparency over hidden mechanics

---

## 2. System Architecture

### 2.1 High-Level Components

```
┌─────────────────────────────────────────────────────┐
│                 Frontend (React/Inertia)             │
│  - Bid forms                                        │
│  - Countdown timers                                  │
│  - Wallet management                                 │
│  - Payment checkout                                  │
└────────────────┬────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────┐
│              Phoenix Controllers                     │
│  - Auction pages (Inertia props)                    │
│  - Bid submission                                    │
│  - Payment webhooks                                  │
└────────────────┬────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────┐
│           Ash Resources (Business Logic)            │
│  - Bid validation & creation                        │
│  - Item lifecycle state machine                     │
│  - Wallet operations                                 │
│  - Order management                                  │
└────────────────┬────────────────────────────────────┘
                 │
        ┌────────┴────────┐
        ▼                 ▼
┌──────────────┐   ┌─────────────────┐
│ Oban Workers │   │ Paystack API    │
│              │   │                 │
│ - Start      │   │ - Split payment │
│ - End        │   │ - Escrow        │
│ - Extend     │   │ - Webhooks      │
│ - Release    │   │                 │
└──────────────┘   └─────────────────┘
```

### 2.2 Auction Lifecycle State Machine

```
draft → scheduled → active → ended → sold/cancelled
           ↓          ↓         ↓
        (Oban job) (bid)  (Oban job + winner determination)
```

**State Transitions:**
- `draft → scheduled`: When published with future start_time
- `scheduled → active`: Oban job at start_time
- `active → ended`: Oban job at end_time (+ extensions)
- `ended → sold`: Winner determined, order created
- `ended → cancelled`: Reserve not met OR no bids
- `active → sold`: Buy Now clicked (immediate end)

### 2.3 Key Design Principles

1. **Idempotent Operations** - Bid processing, winner determination can retry safely
2. **Event-Driven** - Oban jobs trigger state transitions, not web requests
3. **Commission-First** - Deducted at payment time, never honor system
4. **Progressive Trust** - Tiered verification based on transaction value
5. **Wallet as Commitment** - Not full locking (low friction), but signals seriousness
6. **Transparency** - Show reserve exists, show Q&A, show bid history

---

## 3. Phase 1: Core Auction Engine (Weeks 1-6)

### 3.1 Goals

Get auctions working end-to-end with basic bidding, winner determination, and order creation. No payment enforcement yet (honor system).

### 3.2 Enhanced Bid Resource

**New Validations:**

1. **ValidateBidIncrement**
   - Get current_price, calculate required increment based on price tier
   - Increment rules:
     - ₦0-₦10k → ₦100 minimum
     - ₦10k-₦50k → ₦500 minimum
     - ₦50k-₦200k → ₦1,000 minimum
     - ₦200k+ → ₦5,000 minimum
   - Validate: `new_bid >= current_price + increment`

2. **PreventSelfBidding**
   - Check `bid.user_id != item.created_by_id`

3. **AuctionMustBeActive**
   - Check `item.auction_status in [:active, :scheduled]`

4. **ValidateWalletCommitment**
   - <₦50k items: wallet.balance >= ₦1,000
   - ≥₦50k items: wallet.balance >= ₦5,000
   - Check phone verification
   - Check ID verification (for ≥₦50k)

**Implementation Files:**
- `lib/angle/bidding/bid/validate_bid_increment.ex`
- `lib/angle/bidding/bid/prevent_self_bidding.ex`
- `lib/angle/bidding/bid/auction_must_be_active.ex`
- `lib/angle/bidding/bid/validate_wallet_commitment.ex`

### 3.3 Item Lifecycle State Machine

**New Attributes:**
```elixir
attribute :extension_count, :integer, default: 0
attribute :original_end_time, :utc_datetime_usec
```

**Actions:**
```elixir
update :start_auction
update :end_auction
update :extend_auction
```

**Oban Workers:**
- `Angle.Workers.StartAuctionWorker` - Triggered at start_time
- `Angle.Workers.EndAuctionWorker` - Triggered at end_time (+ extensions)

### 3.4 Reserve Price Enforcement

**At Auction End:**
- Check `highest_bid.amount >= item.reserve_price`
- If met → create order, status: sold
- If not met → status: cancelled, notify seller with highest bid amount

**Frontend:**
- Show badge: "🔒 Reserve price set" (not the amount)
- At end: "Reserve met ✓" or "Reserve not met"

### 3.5 Soft Close with Extensions

**Logic:**
- If bid placed in last 10 minutes AND `extension_count < 2`
- Extend `end_time` by 10 minutes
- Increment `extension_count`
- Reschedule `EndAuctionWorker` to new end_time
- Broadcast extension notification

**Implementation:**
- `lib/angle/bidding/bid/check_soft_close_extension.ex`

**Max Extensions:** 2 (max 20 minutes added total)

### 3.6 Winner Determination

**EndAuctionWorker Flow:**
```elixir
1. Get highest valid bid
2. Check reserve price
3. If met:
   - Create Order (status: payment_pending)
   - Update item.auction_status = :sold
   - Notify winner + seller
   - Notify losing bidders
4. If not met:
   - Update item.auction_status = :cancelled
   - Notify seller (reserve not met)
```

### 3.7 Basic Order Flow

**Order States (Phase 1):**
```
payment_pending → paid → dispatched → completed
```

**Actions:**
- `mark_dispatched` - Seller marks after receiving payment
- `confirm_receipt` - Buyer confirms delivery

**Phase 1 Limitation:**
- No payment enforcement (honor system)
- Seller self-reports payment
- Commission tracked but not collected
- Prepares foundation for Phase 2

### 3.8 Notifications

**Email notifications (via Swoosh):**
- Outbid notification
- Won auction
- Lost auction
- Reserve not met (seller)
- Auction extended

---

## 4. Phase 2: Payment & Trust (Weeks 7-11)

### 4.1 Goals

Add Paystack integration, enforce commission, implement tiered verification, seller controls, and escrow for high-value items.

### 4.2 Wallet System

**New Resource: UserWallet**
```elixir
attributes:
  - balance (available funds)
  - total_deposited (lifetime)
  - total_withdrawn (lifetime)

actions:
  - deposit (Paystack → credit wallet)
  - withdraw (wallet → bank account via Paystack)
  - credit_for_sale (seller receives payment)
```

**New Resource: WalletTransaction**
- Audit trail for all wallet operations
- Types: deposit, withdrawal, purchase, sale_credit, refund, commission

**Wallet as Commitment (Not Locking):**
- <₦50k items: Require ₦1,000 minimum balance (commitment signal)
- ≥₦50k items: Require ₦5,000 minimum balance
- NO funds locked during bidding
- After winning, pay via payment link

### 4.3 Payment Integration

**Two Payment Paths:**

**Path 1: Low Value (<₦50k) - Split Payment**
```
1. Winner determined, Order created (payment_pending)
2. Generate Paystack split payment link
3. Buyer pays ₦30,450 (₦30k + 1.5% Paystack fee)
4. Paystack splits instantly:
   - ₦27,600 → Seller subaccount (92%)
   - ₦2,400 → Platform (8% commission)
5. Webhook confirms → Order.status = paid
6. Seller ships, marks dispatched
7. Buyer confirms, Order.status = completed
```

**Path 2: High Value (≥₦50k) - Escrow**
```
1. Winner determined, Order created (payment_pending)
2. Generate Paystack escrow payment link
3. Buyer pays ₦101,500 (₦100k + 1.5% fee)
4. Funds held in Paystack Balance (7 days)
5. Order.status = paid, escrow_release_at = now + 7 days
6. Seller ships, marks dispatched
7. Buyer confirms receipt OR 7 days pass
8. Platform releases funds:
   - ₦94,000 → Seller (94%)
   - ₦6,000 → Platform (6% commission)
9. Order.status = completed
```

**Payment Provider:** Paystack (lower fees, better Nigerian penetration)

**Who Pays Provider Fees:** Buyer (added at checkout, industry standard)

### 4.4 Tiered Verification

**New Resource: UserVerification**
```elixir
attributes:
  - phone_verified (boolean)
  - phone_verified_at
  - id_verified (boolean)
  - id_document_url (S3 upload)
  - id_verification_status (pending/approved/rejected)
```

**Requirements:**

| Item Value | Min Wallet | Verification | Payment |
|------------|-----------|--------------|---------|
| <₦50k | ₦1,000 | Phone | Link (24h) |
| ≥₦50k | ₦5,000 | Phone + ID | Link (24h) + 7-day escrow |

**Phone Verification:** SMS OTP via Termii/Africa's Talking

**ID Verification:** Manual review by admin (upload ID card/driver's license)

### 4.5 Seller Override Window

**2-Hour Window After Auction Ends:**
- Seller can reject winner (with reason dropdown)
- If rejected → offer to 2nd highest bidder
- After 2 hours → winner locked in

**Order Attributes:**
```elixir
attribute :override_expires_at (2 hours from creation)
attribute :override_reason
```

**Action:**
```elixir
update :reject_winner do
  validate override_expires_at not passed
  change status to :cancelled
  offer_to_second_bidder(item_id)
end
```

### 4.6 Blacklist Functionality

**New Resource: SellerBlacklist**
```elixir
attributes:
  - seller_id
  - blocked_user_id
  - reason
```

**Bid Validation:**
- Check if bidder is in seller's blacklist
- Error: "You are not allowed to bid on this seller's items"

**Frontend:**
- Seller dashboard: "Block bidder #47?"
- Blacklist management page

### 4.7 Non-Payment Handling

**24-Hour Payment Window:**
1. Winner gets payment link
2. Reminder at 12 hours
3. Deadline at 24 hours:
   - If not paid → `Order.status = payment_failed`
   - Offer to 2nd highest bidder
   - Track non-payment in reputation
   - After 3 non-payments → suspend bidding privileges

**Workers:**
- `PaymentReminderWorker` (12 hours after order)
- `PaymentDeadlineWorker` (24 hours after order)

---

## 5. Phase 3: Advanced Features (Weeks 12-16)

### 5.1 Buy Now Functionality

**Core Behavior:**
- Hybrid sale_type = auction + optional buy_now_price
- Buy Now ends auction immediately
- First to click wins
- All bidders notified, auction cancelled

**New Attributes:**
```elixir
Item:
  - buy_now_price (decimal)
  - buy_now_enabled (boolean)

Order:
  - source (auction_win | buy_now)
```

**Action:**
```elixir
update :buy_now do
  validate item is active, sale_type = hybrid
  validate wallet commitment
  validate not buying own item

  change auction_status to :sold
  create Order with source: buy_now
  cancel scheduled end job
  notify all bidders
end
```

**Race Condition Handling:**
- Atomic update: `UPDATE items SET auction_status = :sold WHERE id = ? AND auction_status = :active`
- First one wins, others get error

### 5.2 Private Auctions

**Link-Based Access:**

**New Attributes:**
```elixir
Item:
  - visibility (:public | :private)
  - access_token (32-char random string)
```

**Access Control:**
- Private auctions require `?invite=token` in URL
- Token stored in session after first access
- Never appear in search/browse
- Only owner + token holders can view

**Shareable Link:**
```
https://angle.com/items/{id}?invite={access_token}
```

**Frontend:**
- Copy link button
- Share via WhatsApp
- Send via Email
- Access token displayed on seller dashboard

### 5.3 Public Q&A System

**New Resource: ItemQuestion**
```elixir
attributes:
  - item_id
  - asker_id
  - question (max 500 chars)
  - answer (max 1000 chars)
  - answered_at

actions:
  - ask (buyer asks question)
  - answer (seller responds)
  - by_item (list Q&A for item)
  - unanswered_by_seller
```

**Policies:**
- Anyone can read questions on published items
- Logged-in users can ask
- Only seller can answer

**Notifications:**
- Seller: "New question on your item"
- Asker: "Seller answered your question"

**Frontend:**
- Q&A section on item page
- Seller dashboard: "3 unanswered questions"
- Real-time updates when answered

### 5.4 Real-Time Updates

**Phoenix Channels:**

**AuctionChannel** (`auction:{item_id}`):
- Join when viewing active auction
- Broadcasts:
  - `new_bid` - Current price, bid count, anonymized bidder
  - `auction_extended` - New end time, extension message
  - `auction_ended` - Buy now clicked or time expired

**Frontend Hook:**
```tsx
useAuctionChannel(itemId) {
  - Subscribe to channel
  - Update current price in real-time
  - Show bid notifications
  - Update countdown timer on extension
}
```

---

## 6. Data Models & Schema Changes

### 6.1 New Tables

**user_wallets:**
```sql
- id (uuid)
- user_id (uuid, unique, not null)
- balance (decimal, default 0)
- total_deposited (decimal, default 0)
- total_withdrawn (decimal, default 0)
- inserted_at, updated_at
```

**wallet_transactions:**
```sql
- id (uuid)
- wallet_id (uuid, not null)
- type (string: deposit/withdrawal/purchase/sale_credit/refund/commission)
- amount (decimal)
- balance_before (decimal)
- balance_after (decimal)
- reference (string: order_id, paystack_ref)
- description (text)
- metadata (jsonb)
- inserted_at, updated_at
```

**user_verifications:**
```sql
- id (uuid)
- user_id (uuid, unique, not null)
- phone_verified (boolean, default false)
- phone_verified_at (timestamp)
- id_verified (boolean, default false)
- id_document_url (string)
- id_verified_at (timestamp)
- id_verification_status (string: pending/approved/rejected)
- inserted_at, updated_at
```

**paystack_subaccounts:**
```sql
- id (uuid)
- user_id (uuid, unique, not null)
- subaccount_code (string, unique, not null)
- business_name (string)
- bank_code (string)
- account_number (string)
- active (boolean, default true)
- inserted_at, updated_at
```

**seller_blacklists:**
```sql
- id (uuid)
- seller_id (uuid, not null)
- blocked_user_id (uuid, not null)
- reason (text)
- inserted_at, updated_at
- unique index on (seller_id, blocked_user_id)
```

**item_questions:**
```sql
- id (uuid)
- item_id (uuid, not null)
- asker_id (uuid, not null)
- question (text, not null)
- answer (text)
- answered_at (timestamp)
- inserted_at, updated_at
```

### 6.2 Modified Tables

**items - Add columns:**
- extension_count (integer, default 0)
- original_end_time (timestamp)
- buy_now_enabled (boolean, default false)
- visibility (string, default "public")
- access_token (string)

**orders - Add columns:**
- source (string, default "auction_win")
- payment_method (string: split_payment/escrow)
- commission_rate (decimal)
- commission_amount (decimal)
- escrow_release_at (timestamp)
- paystack_transaction_id (string)
- paystack_reference (string)
- override_expires_at (timestamp)
- override_reason (text)

### 6.3 Critical Indexes

```sql
-- Auction queries
CREATE INDEX items_auction_status_end_time_idx ON items (auction_status, end_time);
CREATE INDEX items_visibility_idx ON items (visibility);

-- Bidding queries
CREATE INDEX bids_item_amount_idx ON bids (item_id, amount DESC);

-- Order queries
CREATE INDEX orders_status_escrow_idx ON orders (status, escrow_release_at);

-- Wallet queries
CREATE INDEX wallet_transactions_wallet_time_idx ON wallet_transactions (wallet_id, inserted_at DESC);
```

---

## 7. Error Handling & Edge Cases

### 7.1 Race Conditions

**Problem:** Two users bid simultaneously

**Solution:** Database row-level locking
```elixir
item = Angle.Repo.get!(Item, item_id, lock: "FOR UPDATE")
# Re-check auction still active after acquiring lock
```

**Problem:** Soft close extension race

**Solution:** Atomic increment with condition
```sql
UPDATE items
SET end_time = ?, extension_count = extension_count + 1
WHERE id = ? AND extension_count < 2
```

### 7.2 Payment Failures

**Problem:** Paystack webhook fails/delayed

**Solution 1:** Polling backup
- `VerifyPaymentWorker` scheduled 5 min after payment link
- Polls Paystack API: `verify_transaction(reference)`
- If successful but no webhook → process payment

**Solution 2:** Idempotent webhook handler
- Check `order.status == :payment_pending` before processing
- If already processed → return :ok (idempotent)

### 7.3 Auction End Edge Cases

**Case 1: No bids at all**
- Set status: cancelled
- Notify seller: "No bids received, consider lowering starting price"

**Case 2: Reserve not met**
- Set status: cancelled
- Notify seller: "Highest bid: ₦X, Reserve: ₦Y. Relist or contact bidder?"

**Case 3: Winner doesn't pay (24h timeout)**
- Mark order: payment_failed
- Track non-payment (reputation)
- Offer to 2nd highest bidder

**Case 4: Seller rejects winner (override window)**
- Cancel order
- Offer to 2nd bidder
- If no 2nd bidder → suggest relist

### 7.4 Buy Now Edge Cases

**Case 1: Buy Now during bid submission**

**Solution:** Optimistic locking + atomic update
```sql
UPDATE items SET auction_status = :sold
WHERE id = ? AND auction_status = :active AND buy_now_enabled = true
```

**Case 2: Multiple Buy Now clicks**

**Solution:** First wins (atomic update), others get error

### 7.5 Wallet Edge Cases

**Case 1: Concurrent withdrawals**

**Solution:** Database check constraint
```sql
ALTER TABLE user_wallets ADD CONSTRAINT balance_non_negative CHECK (balance >= 0);
```

**Case 2: User withdraws after placing bid**

**Solution:** Re-validate balance at bid time
- Check `wallet.balance >= commitment_amount`
- Error: "Insufficient balance, please deposit"

---

## 8. Testing Strategy

### 8.1 Unit Tests (Ash Resources)

**Bid Validation Tests:**
- Valid bid higher than current + increment → succeeds
- Bid below increment → fails with clear error
- Insufficient wallet → fails
- Bidding on own item → fails
- Auction not active → fails
- Blacklisted user → fails

**Auction Lifecycle Tests:**
- Scheduled → active transition at start_time
- Active → ended transition at end_time
- Winner determination with multiple bids
- Reserve not met → cancelled
- Soft close extension logic (max 2)

**Wallet Tests:**
- Deposit increases balance
- Withdrawal decreases balance
- Concurrent withdrawal handled (constraint)

### 8.2 Integration Tests (Controllers)

**Bid Controller:**
- POST /items/:id/bids creates bid
- Returns updated item state (current_price, bid_count)
- Returns 422 if validation fails
- Returns 401 if not logged in

**Payment Webhook:**
- Valid Paystack webhook updates order status
- Invalid signature rejected
- Idempotent (duplicate webhooks ignored)

### 8.3 End-to-End Tests (Wallaby)

**Complete Bidding Flow:**
1. Buyer logs in
2. Navigates to item
3. Places bid
4. Sees updated price
5. Auction ends (simulated)
6. Receives email
7. Order created
8. Payment link visible

**Buy Now Flow:**
1. Buyer clicks Buy Now
2. Confirmation dialog
3. Auction ends immediately
4. All bidders notified
5. Payment link generated

### 8.4 Load/Performance Tests

**Stress Test: 100 concurrent bids**
- Simulate 100 users bidding on same item
- Verify no race conditions
- Verify final state consistent
- Check: `item.current_price == highest_bid.amount`

**Target Metrics:**
- 100 concurrent bids complete in <30 seconds
- >80% success rate (some fail due to increment rules, expected)
- Zero data inconsistencies

---

## 9. Deployment & Operations

### 9.1 Oban Configuration

**Queues:**
```elixir
config :angle, Oban,
  queues: [
    default: 10,
    auctions: 20,      # High priority (start, end)
    payments: 15,      # Payment processing, escrow release
    notifications: 5   # Email/SMS notifications
  ]
```

**Job Scheduling:**
- StartAuction: Scheduled at `item.start_time`
- EndAuction: Scheduled at `item.end_time` (rescheduled on extensions)
- EscrowRelease: Scheduled at `order.escrow_release_at`
- PaymentDeadline: 24 hours after order creation

### 9.2 Monitoring

**Key Metrics:**
- Auction completion rate (ended with winner vs cancelled)
- Payment success rate (paid vs failed)
- Average time to payment (order created → paid)
- Non-payment rate (by user, overall)
- Escrow release latency

**Alerts:**
- Oban job failures (auction jobs critical)
- Paystack webhook failures
- Payment success rate <90%
- Non-payment rate >10%

### 9.3 Database Maintenance

**Regular Tasks:**
- Archive completed orders >90 days old
- Clean up expired access tokens for private auctions
- Prune wallet transactions >1 year old (keep summary stats)

---

## 10. Future Enhancements (Phase 4+)

### 10.1 Proxy Bidding (Autobidding)

**Feature:** User sets max bid, system auto-bids up to that amount

**Implementation:**
- New `ProxyBid` resource
- Auto-bid when outbid (up to max)
- Only reveal minimum needed to win

### 10.2 Multiple Buy Now Strategies

**Extensible Design:**
- `Item.buy_now_strategy` field
- Options: `:ends_auction`, `:until_first_bid`, `:always_available`, `:dynamic`
- Seller chooses strategy at listing creation

### 10.3 Advanced Verification

**BVN Verification:**
- Integrate with Nigerian Bank Verification Number
- Higher trust tier

**Seller Reputation Badges:**
- "Verified Seller" (3+ successful sales)
- "Top Seller" (10+ sales, 4.5⭐ rating)
- "Power Seller" (50+ sales)

### 10.4 Invite-Only Auctions

**Beyond Link-Based:**
- Seller invites specific users by email/username
- Invited users get notification
- Can't access without invite (even with link)

### 10.5 Auction Analytics

**Seller Dashboard:**
- Views, watchers, bid activity graph
- Best time to end auctions
- Price optimization suggestions

---

## Appendix A: Monetization Summary

### Commission Structure

| Sale Price | Commission | Example (₦100k sale) |
|------------|-----------|---------------------|
| <₦50k | 8% | ₦8,000 platform, ₦92,000 seller |
| ₦50k-₦200k | 6% | ₦6,000 platform, ₦94,000 seller |
| ₦200k+ | 5% | ₦5,000 platform, ₦95,000 seller |

**Deduction Timing:**
- Low value: At payment (Paystack split)
- High value: At escrow release (after 7 days)

**Additional Revenue (Optional):**
- Featured listings: ₦5k-₦20k
- Seller verification badge: ₦5k/month
- Private auction fee: ₦1k per auction

---

## Appendix B: Key Decisions Made

1. **Wallet as commitment, not full lock** - Lower friction while showing seriousness
2. **Commission-based monetization** - Aligned incentives, familiar model
3. **Buyer pays Paystack fees** - Industry standard, protects margins
4. **Public Q&A only** - Transparency, no private messaging complexity (Phase 1-3)
5. **Hybrid escrow** - Split payment for low-value, escrow for high-value
6. **Buy Now ends auction** - Simple, clear, prevents gaming
7. **Link-based private auctions** - Easy sharing, no complex invite management
8. **Manual ID verification** - Human review for trust (for now)
9. **2 extension limit** - Prevents infinite auction dragging
10. **Phased MVP approach** - Validate fast, iterate based on feedback

---

## Appendix C: Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-02-19 | Wallet commitment (not full lock) | User feedback: full lock too high friction for low-value items |
| 2026-02-19 | ₦1k/<₦50k, ₦5k/≥₦50k thresholds | Market research: sweet spot for commitment signal |
| 2026-02-19 | Public Q&A only (no messaging) | Simplicity, transparency, easier moderation |
| 2026-02-19 | Phased MVP (not big bang) | Risk mitigation, faster time to market |
| 2026-02-19 | Commission 8%/6%/5% | Competitive vs Jumia (15-20%), sustainable margin |

---

**End of Design Document**

*This document will be updated as requirements evolve. Changes will be logged in Appendix C.*
