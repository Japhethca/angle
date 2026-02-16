# My Bids Page Design

## Goal

Build a My Bids page with three tabs (Active, Won, History) that lets users track their bidding activity, manage won auctions through payment and delivery, and view past bid history.

## Figma References

| Design | Node ID | Description |
|--------|---------|-------------|
| Desktop Active | 352-12450 | Active bids with large item cards, outbid badges |
| Mobile Active | 352-12494 | 2-column grid of active bid cards |
| Outbid Badge | 711-7318 | Dismissible "You've been outbid" component |
| Desktop Won | 742-8239 | Won items with payment/delivery actions |
| Mobile Won | 749-10030 | Won items in card layout with full-width actions |
| Desktop History | 749-9679 | Past bids with outcome badges and dates |
| Mobile History | 749-12292 | Past bids in card layout |

## Architecture

### New Resource: `Angle.Bidding.Order`

Created when an auction ends with bids. Tracks the post-auction lifecycle from payment through delivery.

| Field | Type | Description |
|-------|------|-------------|
| id | UUID | Primary key |
| status | OrderStatus enum | payment_pending, paid, dispatched, completed, cancelled |
| amount | Decimal | Winning bid amount |
| payment_reference | String (nullable) | Paystack transaction reference |
| paid_at | DateTime (nullable) | When payment was confirmed |
| dispatched_at | DateTime (nullable) | When seller marked as dispatched |
| completed_at | DateTime (nullable) | When buyer confirmed receipt |
| item_id | UUID | belongs_to Item |
| buyer_id | UUID | belongs_to User (winner) |
| seller_id | UUID | belongs_to User (item owner) |

### Auction Ending

- **Oban job (`EndAuctionWorker`)**: Scheduled for each item's `end_time` when published
- **On execution**: Sets auction_status to ended (no bids) or sold (has bids), creates Order from highest bid
- **Seller early end**: `:end_auction` action on Item triggers the same logic manually
- **Winner determination**: Highest bid amount wins

### Order Lifecycle

```
payment_pending -> paid (buyer pays via Paystack)
    -> dispatched (seller marks as dispatched)
    -> completed (buyer confirms receipt)
```

### Order Actions

| Action | Actor | Transition | Side Effect |
|--------|-------|-----------|-------------|
| pay_order | Buyer | payment_pending -> paid | Paystack transaction, store reference, set paid_at |
| mark_dispatched | Seller | paid -> dispatched | Set dispatched_at |
| confirm_receipt | Buyer | dispatched -> completed | Set completed_at |

### My Bids Tabs - Data Queries

| Tab | Data Source | Logic |
|-----|-----------|-------|
| Active | User's bids on active/scheduled items | Load bids with item relationship; outbid = user's bid < item.current_price |
| Won | Orders where buyer_id = current user | Group by order status for different UI states |
| History | User's bids on ended/sold/cancelled items (excluding won) | Show outcome: "Completed" if won, "Didn't win" if lost |

### Outbid Detection

On page load only (compare user's latest bid vs item.current_price). Real-time notifications are a separate future feature.

### WhatsApp Contact

Won tab shows WhatsApp icon that opens `https://wa.me/{seller.whatsapp_number}?text=Hi, I won the auction for {item.title} on Angle.` using the seller's existing whatsapp_number field.

## Frontend

### Route

`/bids` (protected, requires authentication). Tab via query param: `/bids?tab=active|won|history` (default: active).

### Layout

- Desktop: Left sidebar nav (Active/Won/History) + main content — same pattern as Settings pages
- Mobile: Top horizontal tabs + content below

### Components

```
pages/bids.tsx                         - Main page with tab routing
features/bidding/components/
  bids-layout.tsx                      - Sidebar (desktop) / tabs (mobile) wrapper
  active-bids-list.tsx                 - Active tab content
  active-bid-card.tsx                  - Large horizontal card (desktop) / grid card (mobile)
  won-bids-list.tsx                    - Won tab content
  won-bid-card.tsx                     - Compact row with status + actions
  history-bids-list.tsx                - History tab content
  history-bid-card.tsx                 - Compact row with outcome + date
  outbid-badge.tsx                     - Dismissible "You've been outbid" badge
```

### Active Tab Card Elements

- Item image (large on desktop, square on mobile)
- Item title (links to item page)
- Your bid amount (bold)
- Time left countdown
- Bid count + watching count
- Highest bid amount
- "You've been outbid" dismissible badge (when your bid < current_price)
- "Increase Bid" orange button (links to item page)

### Won Tab Card Elements

- Item thumbnail (small)
- Item title
- Status badge: Payment pending (orange), Awaiting delivery (green), Completed (green)
- Winning amount
- Seller name with verified badge
- Action buttons: Pay (payment_pending), WhatsApp + Confirm Receipt (dispatched)

### History Tab Card Elements

- Item thumbnail (small)
- Item title
- Status badge: Didn't win (gray), Completed (green)
- Your bid amount
- Seller name with verified badge
- Date (auction end date)

### Data Loading

- Default tab (Active) loaded server-side via Inertia props (run_typed_query in controller)
- Tab switches fetch client-side via useAshQuery + RPC typed queries
- Each tab has its own typed query for optimal data loading

## Decisions

- **Order Resource over Bid Status**: Clean separation of auction-time bids from post-auction fulfillment
- **Oban + manual auction ending**: Auto-end at end_time, seller can also end early
- **Paystack for payments**: Use existing integration for won item payments
- **Seller dispatches first**: Paid -> Dispatched -> Completed flow for trust
- **On-page-load outbid detection**: Real-time notifications deferred to future feature
- **WhatsApp for seller contact**: Uses existing whatsapp_number field on User
