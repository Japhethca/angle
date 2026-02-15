# Payments Settings Design

## Goal

Add a Payments section to Settings that lets users manage payment methods (cards via Paystack), payout methods (bank accounts via Paystack), and an auto-charge preference for post-win billing.

## Architecture

### New Ash Domain: `Angle.Payments`

Two resources in a new domain, plus a new attribute on User.

#### PaymentMethod (cards)

| Field | Type | Frontend visible? | Notes |
|-------|------|-------------------|-------|
| id | uuid | yes | PK |
| user_id | uuid | yes | FK to users |
| card_type | string | yes | "visa", "mastercard", etc. |
| last_four | string | yes | Last 4 digits |
| exp_month | integer | yes | |
| exp_year | integer | yes | |
| authorization_code | string | **NEVER** | Paystack token, `sensitive? true` |
| bank | string | yes | Issuing bank name |
| is_default | boolean | yes | default: false |
| paystack_reference | string | **NEVER** | Transaction ref, prevents replay |
| inserted_at | utc_datetime_usec | yes | |
| updated_at | utc_datetime_usec | yes | |

Actions:
- `create` — server-only, called after Paystack verification
- `list_by_user` — public read, excludes authorization_code and paystack_reference
- `read_internal` — private read with all fields (server use only)
- `destroy` — remove a saved card

#### PayoutMethod (bank accounts)

| Field | Type | Frontend visible? | Notes |
|-------|------|-------------------|-------|
| id | uuid | yes | PK |
| user_id | uuid | yes | FK to users |
| bank_name | string | yes | e.g. "Kuda Bank" |
| bank_code | string | no | Paystack bank code |
| account_number | string | yes (masked) | Full stored, masked on frontend |
| account_name | string | yes | Resolved from Paystack |
| recipient_code | string | **NEVER** | Paystack transfer recipient, `sensitive? true` |
| is_default | boolean | yes | default: false |
| inserted_at | utc_datetime_usec | yes | |
| updated_at | utc_datetime_usec | yes | |

Actions:
- `create` — server-only, called after Paystack account resolution + recipient creation
- `list_by_user` — public read, excludes recipient_code, masks account_number
- `destroy` — remove a saved bank account

#### Auto-charge preference

New `auto_charge` boolean on `Angle.Accounts.User` (default: false). New `update_auto_charge` action.

### Paystack Integration

**Module: `Angle.Payments.Paystack`** — wrapper around Paystack REST API using Req.

Endpoints used:
- `POST /transaction/initialize` — Initialize card verification charge (₦50)
- `GET /transaction/verify/:reference` — Verify transaction, extract authorization
- `GET /bank` — List Nigerian banks
- `GET /bank/resolve` — Resolve account number to account name
- `POST /transferrecipient` — Create transfer recipient

API key: `config :angle, :paystack_secret_key` (runtime config, never in JS).

### Security Measures

1. **Sensitive fields**: `authorization_code`, `recipient_code`, `paystack_reference` use `sensitive? true` and are excluded from all frontend-facing actions
2. **Separate read actions**: Internal (all fields) vs. public (safe fields only)
3. **Account number masking**: Full number stored, controller masks before sending to frontend (e.g., "200956****")
4. **Transaction verification**: Server-side only. Card details extracted from Paystack's verified response, never from frontend
5. **Replay prevention**: `paystack_reference` stored on PaymentMethod, unique constraint prevents reuse
6. **Amount validation**: Server verifies the charged amount matches ₦50 (5000 kobo)
7. **Owner-only policies**: All CRUD operations restricted to the owning user
8. **No update actions**: Payment/payout methods are add-or-remove only
9. **PCI compliance**: Raw card numbers never touch our code — Paystack inline popup handles card entry

### Card Addition Flow

1. Frontend calls `POST /rpc/run` → `initialize_card_charge` action
2. Backend calls Paystack `POST /transaction/initialize` with user email, amount=5000 (₦50)
3. Backend returns `authorization_url` and `reference`
4. Frontend opens Paystack inline popup
5. On popup success, frontend calls `POST /rpc/run` → `verify_and_save_card` action with `reference`
6. Backend calls Paystack `GET /transaction/verify/:reference`
7. Backend validates: status=success, amount=5000, reference not already used
8. Backend extracts authorization (card_type, last4, exp_month, exp_year, authorization_code)
9. Backend creates PaymentMethod record
10. Frontend refreshes via Inertia reload

### Bank Account Addition Flow

1. Frontend fetches bank list (cached from Paystack `GET /bank`)
2. User selects bank + enters 10-digit account number
3. Frontend calls `POST /rpc/run` → `add_payout_method` action
4. Backend calls Paystack `GET /bank/resolve` to verify account
5. Backend calls Paystack `POST /transferrecipient` to create recipient
6. Backend creates PayoutMethod record
7. Frontend refreshes via Inertia reload

### Frontend Components

```
features/settings/components/
├── payment-methods-section.tsx   — Card list + Paystack popup trigger
├── payout-methods-section.tsx    — Bank account list + add form/dialog
├── auto-charge-section.tsx       — Toggle with description

pages/settings/
├── payments.tsx                  — Wraps all 3 in SettingsLayout
```

### Controller

`SettingsController.payments/2` loads:
- `payment_methods` — user's cards (safe fields only, via public read action)
- `payout_methods` — user's bank accounts (account numbers masked)
- `user` — includes auto_charge preference

### UI Details (from Figma)

- Payment method card: card type icon (Visa/Mastercard) + masked number + expiry + kebab menu (with Remove)
- Payout method card: bank icon + bank name + masked account number + "default" badge + Remove link
- Auto-charge: shadcn Switch with label and description text
- "+ New Payment Method" and "+ New Payout Method" links in primary color
