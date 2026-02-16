# Image Upload System Design

## Goal

Add image upload support for item listings (up to 10 images), user avatars, and store logos. Images are uploaded through Phoenix, processed into bandwidth-optimized variants using libvips, and stored on Cloudflare R2.

## Architecture

Server-side upload flow: browser sends files to Phoenix, which validates, generates variants, uploads to R2, and stores metadata in Postgres. A new `Angle.Media` domain owns the `Image` resource.

**Stack:**
- **Storage:** Cloudflare R2 (S3-compatible, $0 egress, ~$0-2/mo at early scale)
- **Processing:** `image` Elixir library (libvips wrapper) for resize + webp conversion
- **Upload:** Phoenix controller handling multipart/form-data
- **Serving:** R2 public bucket URL (behind Cloudflare CDN)

## Data Model

### Image Resource (`Angle.Media.Image`)

| Field | Type | Description |
|-------|------|-------------|
| id | uuid | Primary key |
| owner_type | enum(:item, :user_avatar, :store_logo) | Polymorphic owner type |
| owner_id | uuid | ID of the owning item/user/store_profile |
| storage_key | string | R2 key for original (e.g. `items/abc123/original.webp`) |
| variants | map | `{"thumbnail": "items/abc123/thumb.webp", "medium": "...", "full": "..."}` |
| position | integer | Ordering for item galleries (0 = cover image). Always 0 for avatars/logos. |
| file_size | integer | Original file size in bytes |
| mime_type | string | Original MIME type |
| width | integer | Original width in pixels |
| height | integer | Original height in pixels |
| inserted_at | datetime | |
| updated_at | datetime | |

**Constraints:**
- Unique: `[:owner_type, :owner_id, :position]` (no duplicate positions)
- Max 10 images per item
- Max 1 avatar per user
- Max 1 logo per store profile

## Upload Flow

```
1. Browser: POST /uploads (multipart: file + owner_type + owner_id)
2. Phoenix: Authenticate user, verify ownership of owner_id
3. Phoenix: Validate file (type, size, count limit)
4. Phoenix: Generate 3 variants via libvips → all webp
5. Phoenix: Upload original + variants to R2
6. Phoenix: Create Image record in Postgres
7. Phoenix: Return { id, variants, position }
```

## Image Variants

| Variant | Max Width | Quality | Approx Size | Use Case |
|---------|-----------|---------|-------------|----------|
| thumbnail | 200px | 80% | 10-20KB | Item cards, grids, search results |
| medium | 600px | 85% | 50-80KB | Mobile item detail, store profiles |
| full | 1200px | 90% | 150-200KB | Desktop gallery, full-screen view |

All variants maintain aspect ratio and are converted to webp format.

## API Endpoints

### Upload

```
POST /uploads
  Content-Type: multipart/form-data
  Body: file, owner_type, owner_id
  Auth: required (must own the entity)
  Response: 201 { id, storageKey, variants, position, width, height }
```

### Delete

```
DELETE /uploads/:id
  Auth: required (must own the image)
  Response: 204
```

### Reorder (item images only)

```
PATCH /uploads/reorder
  Body: { item_id, image_ids: ["id1", "id2", ...] }
  Auth: required (must own the item)
  Response: 200 { images: [...] }
```

## Validation Rules

| Rule | Value |
|------|-------|
| Max file size | 10 MB |
| Accepted MIME types | image/jpeg, image/png, image/webp |
| Max images per item | 10 |
| Max avatars per user | 1 (replace existing) |
| Max logos per store | 1 (replace existing) |

## Frontend Components

### Shared

- **`<ImageUploader />`** - Drop zone + file picker with upload progress and preview. Configurable for single (avatar/logo) or multi (item) mode.

### Item Images

- **`<ItemImageManager />`** - Multi-image upload for create/edit item forms. Drag-to-reorder, set cover image, delete.
- **`<ImageGallery />`** - Item detail page gallery. Thumbnail strip + main image viewer. Replaces current Gavel icon placeholders.
- **`<ItemCardImage />`** - Thumbnail variant in item cards/grids. Replaces grey placeholder boxes.

### Profile Images

- **`<AvatarUpload />`** - Single image upload for Settings > Profile. Replaces User icon placeholder.
- **`<StoreLogoUpload />`** - Single image upload for Settings > Store. Replaces Store icon placeholder.

## Image URL Serving

R2 public bucket with base URL configured in app config. Frontend constructs full URLs:

```tsx
const IMAGE_BASE_URL = "https://<account>.r2.dev/<bucket>";
// or custom domain: "https://images.angle.ng"

<img src={`${IMAGE_BASE_URL}/${image.variants.thumbnail}`} />
```

No signed URLs for reads — images are publicly accessible.

## Where Images Appear in UI

| Page | Image Type | Variant Used |
|------|-----------|-------------|
| Homepage item cards | Item cover | thumbnail |
| Category browse grid | Item cover | thumbnail |
| Search results | Item cover | thumbnail |
| Item detail gallery | All item images | medium (mobile), full (desktop) |
| Won bids / order cards | Item cover | thumbnail |
| Watchlist cards | Item cover | thumbnail |
| Store profile header | Store logo | medium |
| Seller store page | Store logo + item covers | medium + thumbnail |
| Nav user menu | User avatar | thumbnail |
| Settings profile page | User avatar | medium |

## Processing Library

The [`image`](https://hex.pm/packages/image) Elixir library (wraps libvips):
- Faster and lower memory than ImageMagick
- Native webp support
- Clean Elixir API for resize, crop, format conversion

**System dependency:** libvips must be installed on the server/Docker image.

## R2 Configuration

- **Bucket:** `angle-images` (or similar)
- **Region:** Auto (Cloudflare picks closest)
- **Public access:** Enabled (for serving images via URL)
- **CORS:** Not needed (uploads go through Phoenix, not direct)
- **Elixir client:** `ex_aws` + `ex_aws_s3` (R2 is S3-compatible)

## Error Handling

| Error | HTTP Status | User Message |
|-------|-------------|-------------|
| File too large | 413 | "Image must be under 10MB" |
| Invalid file type | 422 | "Only JPEG, PNG, and WebP images are accepted" |
| Too many images | 422 | "Maximum 10 images per listing" |
| Processing failure | 422 | "Could not process this image. Try a different file." |
| R2 upload failure | 500 | "Upload failed. Please try again." |
| Not authorized | 403 | "You don't have permission to upload here" |

## Dependencies to Add

- `image` - libvips wrapper for Elixir (image processing)
- `ex_aws` - AWS client core
- `ex_aws_s3` - S3 operations (R2 compatible)
- `sweet_xml` - Required by ex_aws for XML parsing

## Config

```elixir
# config/config.exs
config :ex_aws,
  access_key_id: System.get_env("R2_ACCESS_KEY_ID"),
  secret_access_key: System.get_env("R2_SECRET_ACCESS_KEY"),
  region: "auto"

config :ex_aws, :s3,
  scheme: "https://",
  host: "<account_id>.r2.cloudflarestorage.com",
  region: "auto"

config :angle, Angle.Media,
  bucket: "angle-images",
  base_url: System.get_env("IMAGE_BASE_URL")  # e.g. "https://images.angle.ng"
```
