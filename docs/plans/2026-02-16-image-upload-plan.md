# Image Upload Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add image upload for item listings (up to 10), user avatars, and store logos — processed into webp variants via libvips, stored on Cloudflare R2.

**Architecture:** Server-side upload through Phoenix controller. Files are validated, processed into 3 variants (thumbnail/medium/full) using the `image` library (libvips), uploaded to R2 via `ex_aws_s3`, and tracked in a polymorphic `images` table via an Ash resource in a new `Angle.Media` domain.

**Tech Stack:** Elixir `image` (libvips), `ex_aws` + `ex_aws_s3` (R2), Phoenix controller (multipart), React dropzone + progress UI.

**Design doc:** `docs/plans/2026-02-16-image-upload-design.md`

---

## Task 1: Add Dependencies

**Files:**
- Modify: `mix.exs`
- Modify: `config/config.exs`
- Modify: `config/dev.exs`
- Modify: `config/runtime.exs`

**Step 1: Add deps to mix.exs**

Add to the `deps` function in `mix.exs`:

```elixir
{:image, "~> 0.54"},
{:ex_aws, "~> 2.5"},
{:ex_aws_s3, "~> 2.5"},
{:sweet_xml, "~> 0.7"},
```

**Step 2: Install dependencies**

Run: `mix deps.get`
Expected: All four packages resolve and download.

**Step 3: Add R2/S3 config**

In `config/config.exs`, add at the end (before `import_config`):

```elixir
# Cloudflare R2 (S3-compatible) for image storage
config :ex_aws,
  json_codec: Jason,
  region: "auto"

config :angle, Angle.Media,
  bucket: "angle-images",
  base_url: "https://images.angle.ng"
```

In `config/dev.exs`, add:

```elixir
# R2 credentials for dev (set in .env or shell)
config :ex_aws,
  access_key_id: System.get_env("R2_ACCESS_KEY_ID", "test"),
  secret_access_key: System.get_env("R2_SECRET_ACCESS_KEY", "test")

config :ex_aws, :s3,
  scheme: "https://",
  host: System.get_env("R2_ENDPOINT", "localhost"),
  region: "auto"

config :angle, Angle.Media,
  bucket: System.get_env("R2_BUCKET", "angle-images-dev"),
  base_url: System.get_env("IMAGE_BASE_URL", "http://localhost:4000/uploads")
```

In `config/runtime.exs`, add inside the `if config_env() == :prod do` block:

```elixir
config :ex_aws,
  access_key_id: System.fetch_env!("R2_ACCESS_KEY_ID"),
  secret_access_key: System.fetch_env!("R2_SECRET_ACCESS_KEY")

config :ex_aws, :s3,
  scheme: "https://",
  host: System.fetch_env!("R2_ENDPOINT"),
  region: "auto"

config :angle, Angle.Media,
  bucket: System.fetch_env!("R2_BUCKET"),
  base_url: System.fetch_env!("IMAGE_BASE_URL")
```

In `config/test.exs`, add:

```elixir
config :angle, Angle.Media,
  bucket: "angle-images-test",
  base_url: "http://localhost:9000/angle-images-test",
  storage_module: Angle.Media.Storage.Mock
```

**Step 4: Verify compilation**

Run: `mix compile`
Expected: Compiles with 0 errors.

**Step 5: Commit**

```bash
git add mix.exs mix.lock config/config.exs config/dev.exs config/runtime.exs config/test.exs
git commit -m "chore: add image upload dependencies (image, ex_aws, ex_aws_s3)"
```

---

## Task 2: Create Media Domain and Image Resource

**Files:**
- Create: `lib/angle/media.ex`
- Create: `lib/angle/media/image.ex`
- Modify: `config/config.exs` (register domain)

**Step 1: Write the Image resource test**

Create `test/angle/media/image_test.exs`:

```elixir
defmodule Angle.Media.ImageTest do
  use Angle.DataCase, async: true

  alias Angle.Media.Image

  setup do
    user = Angle.Factory.create_user()
    item = Angle.Factory.create_item(user: user, title: "Test Item")
    %{user: user, item: item}
  end

  describe "create action" do
    test "creates an image for an item", %{user: user, item: item} do
      assert {:ok, image} =
               Image
               |> Ash.Changeset.for_create(:create, %{
                 owner_type: :item,
                 owner_id: item.id,
                 storage_key: "items/#{item.id}/original.webp",
                 variants: %{
                   "thumbnail" => "items/#{item.id}/thumb.webp",
                   "medium" => "items/#{item.id}/medium.webp",
                   "full" => "items/#{item.id}/full.webp"
                 },
                 position: 0,
                 file_size: 150_000,
                 mime_type: "image/webp",
                 width: 1200,
                 height: 800
               }, actor: user)
               |> Ash.create()

      assert image.owner_type == :item
      assert image.owner_id == item.id
      assert image.position == 0
      assert image.variants["thumbnail"] == "items/#{item.id}/thumb.webp"
    end

    test "creates an avatar image for a user", %{user: user} do
      assert {:ok, image} =
               Image
               |> Ash.Changeset.for_create(:create, %{
                 owner_type: :user_avatar,
                 owner_id: user.id,
                 storage_key: "avatars/#{user.id}/original.webp",
                 variants: %{
                   "thumbnail" => "avatars/#{user.id}/thumb.webp",
                   "medium" => "avatars/#{user.id}/medium.webp",
                   "full" => "avatars/#{user.id}/full.webp"
                 },
                 position: 0,
                 file_size: 50_000,
                 mime_type: "image/webp",
                 width: 400,
                 height: 400
               }, actor: user)
               |> Ash.create()

      assert image.owner_type == :user_avatar
    end

    test "enforces unique position per owner", %{user: user, item: item} do
      base_attrs = %{
        owner_type: :item,
        owner_id: item.id,
        storage_key: "items/#{item.id}/original.webp",
        variants: %{},
        position: 0,
        file_size: 100,
        mime_type: "image/webp",
        width: 100,
        height: 100
      }

      {:ok, _} =
        Image
        |> Ash.Changeset.for_create(:create, base_attrs, actor: user)
        |> Ash.create()

      assert {:error, _} =
               Image
               |> Ash.Changeset.for_create(:create, %{base_attrs | storage_key: "items/#{item.id}/other.webp"}, actor: user)
               |> Ash.create()
    end
  end

  describe "destroy action" do
    test "deletes an image", %{user: user, item: item} do
      {:ok, image} =
        Image
        |> Ash.Changeset.for_create(:create, %{
          owner_type: :item,
          owner_id: item.id,
          storage_key: "items/#{item.id}/original.webp",
          variants: %{},
          position: 0,
          file_size: 100,
          mime_type: "image/webp",
          width: 100,
          height: 100
        }, actor: user)
        |> Ash.create()

      assert :ok =
               image
               |> Ash.Changeset.for_destroy(:destroy, %{}, actor: user)
               |> Ash.destroy()
    end
  end

  describe "by_owner read action" do
    test "lists images for an owner", %{user: user, item: item} do
      for i <- 0..2 do
        Image
        |> Ash.Changeset.for_create(:create, %{
          owner_type: :item,
          owner_id: item.id,
          storage_key: "items/#{item.id}/original_#{i}.webp",
          variants: %{},
          position: i,
          file_size: 100,
          mime_type: "image/webp",
          width: 100,
          height: 100
        }, actor: user)
        |> Ash.create!()
      end

      images =
        Image
        |> Ash.Query.for_read(:by_owner, %{owner_type: :item, owner_id: item.id}, actor: user)
        |> Ash.read!()

      assert length(images) == 3
      assert Enum.map(images, & &1.position) == [0, 1, 2]
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/angle/media/image_test.exs`
Expected: FAIL — `Angle.Media.Image` module not found.

**Step 3: Create the Media domain**

Create `lib/angle/media.ex`:

```elixir
defmodule Angle.Media do
  use Ash.Domain,
    otp_app: :angle,
    extensions: [AshTypescript.Rpc]

  resources do
    resource Angle.Media.Image
  end
end
```

**Step 4: Create the Image resource**

Create `lib/angle/media/image.ex`:

```elixir
defmodule Angle.Media.Image do
  use Ash.Resource,
    otp_app: :angle,
    domain: Angle.Media,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshTypescript.Resource]

  postgres do
    table "images"
    repo Angle.Repo
  end

  typescript do
    type_name "Image"
  end

  actions do
    defaults [:read]

    create :create do
      accept [
        :owner_type,
        :owner_id,
        :storage_key,
        :variants,
        :position,
        :file_size,
        :mime_type,
        :width,
        :height
      ]

      primary? true
    end

    destroy :destroy do
      primary? true
    end

    read :by_owner do
      argument :owner_type, :atom do
        allow_nil? false
        constraints one_of: [:item, :user_avatar, :store_logo]
      end

      argument :owner_id, :uuid do
        allow_nil? false
      end

      filter expr(owner_type == ^arg(:owner_type) and owner_id == ^arg(:owner_id))

      prepare build(sort: [position: :asc])
    end

    update :reorder do
      accept [:position]
    end
  end

  policies do
    policy action(:read) do
      authorize_if always()
    end

    policy action(:create) do
      authorize_if actor_present()
    end

    policy action(:destroy) do
      authorize_if actor_present()
    end

    policy action(:reorder) do
      authorize_if actor_present()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :owner_type, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:item, :user_avatar, :store_logo]
    end

    attribute :owner_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :storage_key, :string do
      allow_nil? false
      public? true
    end

    attribute :variants, :map do
      allow_nil? false
      default %{}
      public? true
    end

    attribute :position, :integer do
      allow_nil? false
      default 0
      public? true
    end

    attribute :file_size, :integer do
      allow_nil? false
      public? true
    end

    attribute :mime_type, :string do
      allow_nil? false
      public? true
    end

    attribute :width, :integer do
      allow_nil? false
      public? true
    end

    attribute :height, :integer do
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_position, [:owner_type, :owner_id, :position]
  end
end
```

**Step 5: Register domain in config**

In `config/config.exs`, add `Angle.Media` to the `ash_domains` list:

```elixir
config :angle,
  ash_domains: [Angle.Accounts, Angle.Catalog, Angle.Inventory, Angle.Bidding, Angle.Media]
```

**Step 6: Generate migration and migrate**

Run: `mix ash.codegen --dev && mix ash.migrate`
Expected: Migration created and applied, `images` table exists.

**Step 7: Run tests**

Run: `mix test test/angle/media/image_test.exs`
Expected: All tests pass.

**Step 8: Run full test suite**

Run: `mix test`
Expected: All tests pass (no regressions).

**Step 9: Commit**

```bash
git add lib/angle/media.ex lib/angle/media/image.ex test/angle/media/image_test.exs config/config.exs priv/repo/migrations/
git commit -m "feat: add Media domain with Image resource"
```

---

## Task 3: Image Processing Module

**Files:**
- Create: `lib/angle/media/processor.ex`
- Create: `test/angle/media/processor_test.exs`
- Create: `test/support/fixtures/test_image.jpg` (small test image)

**Step 1: Create a test fixture image**

Generate a small test JPEG programmatically in the test setup, or create a 100x100 test image. We'll generate it in the test using the `image` library itself.

**Step 2: Write the processor test**

Create `test/angle/media/processor_test.exs`:

```elixir
defmodule Angle.Media.ProcessorTest do
  use ExUnit.Case, async: true

  alias Angle.Media.Processor

  @fixture_path "test/support/fixtures"

  setup_all do
    # Create a test image fixture using vips
    File.mkdir_p!(@fixture_path)
    path = Path.join(@fixture_path, "test_image.jpg")

    unless File.exists?(path) do
      {:ok, image} = Image.new(200, 200, color: :red)
      Image.write(image, path)
    end

    %{image_path: path}
  end

  describe "generate_variants/1" do
    test "generates thumbnail, medium, and full variants", %{image_path: path} do
      assert {:ok, result} = Processor.generate_variants(path)

      assert Map.has_key?(result, :thumbnail)
      assert Map.has_key?(result, :medium)
      assert Map.has_key?(result, :full)

      # All variant files should exist
      for {_name, variant_path} <- result do
        assert File.exists?(variant_path), "Variant file should exist: #{variant_path}"
      end

      # All should be webp
      for {_name, variant_path} <- result do
        assert String.ends_with?(variant_path, ".webp")
      end
    end

    test "returns original dimensions", %{image_path: path} do
      assert {:ok, result} = Processor.generate_variants(path)
      assert result.original_width == 200
      assert result.original_height == 200
    end

    test "cleans up temp files on cleanup call", %{image_path: path} do
      assert {:ok, result} = Processor.generate_variants(path)

      for {_name, variant_path} <- result, is_binary(variant_path) do
        assert File.exists?(variant_path)
      end

      Processor.cleanup(result)

      for {_name, variant_path} <- result, is_binary(variant_path) do
        refute File.exists?(variant_path)
      end
    end
  end

  describe "validate_file/1" do
    test "accepts jpeg", %{image_path: path} do
      assert :ok = Processor.validate_file(path, "image/jpeg")
    end

    test "accepts png" do
      assert :ok = Processor.validate_file("test.png", "image/png")
    end

    test "accepts webp" do
      assert :ok = Processor.validate_file("test.webp", "image/webp")
    end

    test "rejects unsupported types" do
      assert {:error, :invalid_type} = Processor.validate_file("test.gif", "image/gif")
    end

    test "rejects files over 10MB" do
      assert {:error, :file_too_large} = Processor.validate_file_size(11_000_000)
    end

    test "accepts files under 10MB" do
      assert :ok = Processor.validate_file_size(5_000_000)
    end
  end
end
```

**Step 3: Run test to verify it fails**

Run: `mix test test/angle/media/processor_test.exs`
Expected: FAIL — `Angle.Media.Processor` module not found.

**Step 4: Implement the processor**

Create `lib/angle/media/processor.ex`:

```elixir
defmodule Angle.Media.Processor do
  @moduledoc """
  Processes uploaded images into optimized webp variants using libvips.
  """

  @max_file_size 10 * 1024 * 1024
  @accepted_types ~w(image/jpeg image/png image/webp)

  @variants [
    {:thumbnail, 200, 80},
    {:medium, 600, 85},
    {:full, 1200, 90}
  ]

  @doc """
  Validates file MIME type.
  """
  def validate_file(_path, mime_type) when mime_type in @accepted_types, do: :ok
  def validate_file(_path, _mime_type), do: {:error, :invalid_type}

  @doc """
  Validates file size in bytes.
  """
  def validate_file_size(size) when size <= @max_file_size, do: :ok
  def validate_file_size(_size), do: {:error, :file_too_large}

  @doc """
  Generates thumbnail, medium, and full webp variants from an image file.

  Returns `{:ok, %{thumbnail: path, medium: path, full: path, original_width: int, original_height: int}}`
  """
  def generate_variants(source_path) do
    with {:ok, image} <- Image.open(source_path) do
      {original_width, original_height, _bands} = Image.shape(image)
      tmp_dir = System.tmp_dir!()

      results =
        Enum.reduce_while(@variants, %{}, fn {name, max_width, quality}, acc ->
          output_path = Path.join(tmp_dir, "#{:erlang.unique_integer([:positive])}_#{name}.webp")

          case resize_and_save(image, output_path, max_width, quality, original_width) do
            :ok ->
              {:cont, Map.put(acc, name, output_path)}

            {:error, reason} ->
              # Clean up already-created files
              Enum.each(acc, fn {_k, path} -> File.rm(path) end)
              {:halt, {:error, reason}}
          end
        end)

      case results do
        {:error, _} = error ->
          error

        variants_map ->
          {:ok,
           Map.merge(variants_map, %{
             original_width: original_width,
             original_height: original_height
           })}
      end
    end
  end

  @doc """
  Removes temporary variant files.
  """
  def cleanup(result) do
    for {key, path} <- result, key in [:thumbnail, :medium, :full], is_binary(path) do
      File.rm(path)
    end

    :ok
  end

  defp resize_and_save(image, output_path, max_width, quality, original_width) do
    resized =
      if original_width > max_width do
        case Image.thumbnail(image, max_width) do
          {:ok, resized} -> resized
          {:error, _} = err -> err
        end
      else
        image
      end

    case resized do
      {:error, _} = err ->
        err

      resized_image ->
        case Image.write(resized_image, output_path, quality: quality) do
          {:ok, _} -> :ok
          {:error, _} = err -> err
        end
    end
  end
end
```

**Step 5: Run tests**

Run: `mix test test/angle/media/processor_test.exs`
Expected: All tests pass.

**Step 6: Commit**

```bash
git add lib/angle/media/processor.ex test/angle/media/processor_test.exs test/support/fixtures/
git commit -m "feat: add image processor with variant generation"
```

---

## Task 4: R2 Storage Module

**Files:**
- Create: `lib/angle/media/storage.ex`
- Create: `lib/angle/media/storage/r2.ex`
- Create: `lib/angle/media/storage/mock.ex`
- Create: `test/angle/media/storage_test.exs`

This task uses a behaviour pattern so tests can use a mock storage instead of hitting R2.

**Step 1: Write the storage behaviour and mock**

Create `lib/angle/media/storage.ex`:

```elixir
defmodule Angle.Media.Storage do
  @moduledoc """
  Behaviour for image storage backends. Dispatches to configured module.
  """

  @callback upload(local_path :: String.t(), remote_key :: String.t(), content_type :: String.t()) ::
              :ok | {:error, term()}

  @callback delete(remote_key :: String.t()) :: :ok | {:error, term()}

  @callback url(remote_key :: String.t()) :: String.t()

  def upload(local_path, remote_key, content_type) do
    impl().upload(local_path, remote_key, content_type)
  end

  def delete(remote_key) do
    impl().delete(remote_key)
  end

  def url(remote_key) do
    config = Application.get_env(:angle, Angle.Media)
    "#{config[:base_url]}/#{remote_key}"
  end

  defp impl do
    config = Application.get_env(:angle, Angle.Media)
    config[:storage_module] || Angle.Media.Storage.R2
  end
end
```

Create `lib/angle/media/storage/r2.ex`:

```elixir
defmodule Angle.Media.Storage.R2 do
  @moduledoc """
  Cloudflare R2 storage backend (S3-compatible).
  """

  @behaviour Angle.Media.Storage

  @impl true
  def upload(local_path, remote_key, content_type) do
    bucket = bucket()

    local_path
    |> ExAws.S3.Upload.stream_file()
    |> ExAws.S3.upload(bucket, remote_key, content_type: content_type, acl: :public_read)
    |> ExAws.request()
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def delete(remote_key) do
    bucket()
    |> ExAws.S3.delete_object(remote_key)
    |> ExAws.request()
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp bucket do
    config = Application.get_env(:angle, Angle.Media)
    config[:bucket]
  end
end
```

Create `lib/angle/media/storage/mock.ex`:

```elixir
defmodule Angle.Media.Storage.Mock do
  @moduledoc """
  Mock storage for tests. Stores uploads in an Agent process.
  """

  @behaviour Angle.Media.Storage

  @impl true
  def upload(_local_path, _remote_key, _content_type) do
    :ok
  end

  @impl true
  def delete(_remote_key) do
    :ok
  end
end
```

**Step 2: Write storage tests**

Create `test/angle/media/storage_test.exs`:

```elixir
defmodule Angle.Media.StorageTest do
  use ExUnit.Case, async: true

  alias Angle.Media.Storage

  describe "url/1" do
    test "constructs full URL from remote key" do
      url = Storage.url("items/abc/thumb.webp")
      # Uses base_url from test config
      assert url =~ "items/abc/thumb.webp"
      assert url =~ "http"
    end
  end

  describe "mock storage" do
    test "upload succeeds" do
      assert :ok = Angle.Media.Storage.Mock.upload("/tmp/test.webp", "items/abc/test.webp", "image/webp")
    end

    test "delete succeeds" do
      assert :ok = Angle.Media.Storage.Mock.delete("items/abc/test.webp")
    end
  end
end
```

**Step 3: Run tests**

Run: `mix test test/angle/media/storage_test.exs`
Expected: All tests pass.

**Step 4: Commit**

```bash
git add lib/angle/media/storage.ex lib/angle/media/storage/r2.ex lib/angle/media/storage/mock.ex test/angle/media/storage_test.exs
git commit -m "feat: add storage behaviour with R2 and mock backends"
```

---

## Task 5: Upload Controller

**Files:**
- Create: `lib/angle_web/controllers/upload_controller.ex`
- Modify: `lib/angle_web/router.ex`
- Create: `test/angle_web/controllers/upload_controller_test.exs`

**Step 1: Write controller tests**

Create `test/angle_web/controllers/upload_controller_test.exs`:

```elixir
defmodule AngleWeb.UploadControllerTest do
  use AngleWeb.ConnCase, async: true

  @fixture_path "test/support/fixtures"

  setup do
    user = Angle.Factory.create_user()
    item = Angle.Factory.create_item(user: user, title: "Test Item")

    # Ensure test image exists
    File.mkdir_p!(@fixture_path)
    image_path = Path.join(@fixture_path, "test_image.jpg")

    unless File.exists?(image_path) do
      {:ok, image} = Image.new(200, 200, color: :red)
      Image.write(image, image_path)
    end

    upload = %Plug.Upload{
      path: image_path,
      content_type: "image/jpeg",
      filename: "test_image.jpg"
    }

    %{user: user, item: item, upload: upload}
  end

  describe "POST /uploads" do
    test "uploads an image for an item", %{conn: conn, user: user, item: item, upload: upload} do
      conn =
        conn
        |> log_in_user(user)
        |> post("/uploads", %{
          "file" => upload,
          "owner_type" => "item",
          "owner_id" => item.id
        })

      assert %{"id" => id, "variants" => variants, "position" => 0} =
               json_response(conn, 201)

      assert is_binary(id)
      assert Map.has_key?(variants, "thumbnail")
      assert Map.has_key?(variants, "medium")
      assert Map.has_key?(variants, "full")
    end

    test "uploads an avatar for a user", %{conn: conn, user: user, upload: upload} do
      conn =
        conn
        |> log_in_user(user)
        |> post("/uploads", %{
          "file" => upload,
          "owner_type" => "user_avatar",
          "owner_id" => user.id
        })

      assert %{"id" => _, "position" => 0} = json_response(conn, 201)
    end

    test "rejects unauthenticated uploads", %{conn: conn, item: item, upload: upload} do
      conn =
        post(conn, "/uploads", %{
          "file" => upload,
          "owner_type" => "item",
          "owner_id" => item.id
        })

      assert conn.status in [401, 302]
    end

    test "rejects invalid MIME type", %{conn: conn, user: user, item: item} do
      upload = %Plug.Upload{
        path: "test/support/fixtures/test_image.jpg",
        content_type: "image/gif",
        filename: "test.gif"
      }

      conn =
        conn
        |> log_in_user(user)
        |> post("/uploads", %{
          "file" => upload,
          "owner_type" => "item",
          "owner_id" => item.id
        })

      assert %{"error" => _} = json_response(conn, 422)
    end

    test "rejects uploads for items the user doesn't own", %{conn: conn, item: item, upload: upload} do
      other_user = Angle.Factory.create_user()

      conn =
        conn
        |> log_in_user(other_user)
        |> post("/uploads", %{
          "file" => upload,
          "owner_type" => "item",
          "owner_id" => item.id
        })

      assert conn.status == 403
    end

    test "auto-increments position for item images", %{conn: conn, user: user, item: item, upload: upload} do
      # Upload first image
      conn
      |> log_in_user(user)
      |> post("/uploads", %{"file" => upload, "owner_type" => "item", "owner_id" => item.id})

      # Upload second image
      conn2 =
        conn
        |> recycle()
        |> log_in_user(user)
        |> post("/uploads", %{"file" => upload, "owner_type" => "item", "owner_id" => item.id})

      assert %{"position" => 1} = json_response(conn2, 201)
    end

    test "replaces existing avatar on re-upload", %{conn: conn, user: user, upload: upload} do
      # Upload first avatar
      conn
      |> log_in_user(user)
      |> post("/uploads", %{"file" => upload, "owner_type" => "user_avatar", "owner_id" => user.id})

      # Upload second avatar (should replace)
      conn2 =
        conn
        |> recycle()
        |> log_in_user(user)
        |> post("/uploads", %{"file" => upload, "owner_type" => "user_avatar", "owner_id" => user.id})

      assert %{"position" => 0} = json_response(conn2, 201)

      # Only one avatar should exist
      images =
        Angle.Media.Image
        |> Ash.Query.for_read(:by_owner, %{owner_type: :user_avatar, owner_id: user.id}, authorize?: false)
        |> Ash.read!()

      assert length(images) == 1
    end
  end

  describe "DELETE /uploads/:id" do
    test "deletes an image", %{conn: conn, user: user, item: item, upload: upload} do
      # Create an image first
      create_conn =
        conn
        |> log_in_user(user)
        |> post("/uploads", %{"file" => upload, "owner_type" => "item", "owner_id" => item.id})

      %{"id" => image_id} = json_response(create_conn, 201)

      # Delete it
      delete_conn =
        conn
        |> recycle()
        |> log_in_user(user)
        |> delete("/uploads/#{image_id}")

      assert delete_conn.status == 204
    end

    test "rejects deletion by non-owner", %{conn: conn, user: user, item: item, upload: upload} do
      create_conn =
        conn
        |> log_in_user(user)
        |> post("/uploads", %{"file" => upload, "owner_type" => "item", "owner_id" => item.id})

      %{"id" => image_id} = json_response(create_conn, 201)

      other_user = Angle.Factory.create_user()

      delete_conn =
        conn
        |> recycle()
        |> log_in_user(other_user)
        |> delete("/uploads/#{image_id}")

      assert delete_conn.status == 403
    end
  end

  describe "PATCH /uploads/reorder" do
    test "reorders item images", %{conn: conn, user: user, item: item, upload: upload} do
      # Create 3 images
      ids =
        for _ <- 0..2 do
          resp =
            conn
            |> recycle()
            |> log_in_user(user)
            |> post("/uploads", %{"file" => upload, "owner_type" => "item", "owner_id" => item.id})
            |> json_response(201)

          resp["id"]
        end

      # Reverse order
      reversed = Enum.reverse(ids)

      reorder_conn =
        conn
        |> recycle()
        |> log_in_user(user)
        |> patch("/uploads/reorder", %{"item_id" => item.id, "image_ids" => reversed})

      assert %{"images" => images} = json_response(reorder_conn, 200)
      assert Enum.map(images, & &1["id"]) == reversed
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `mix test test/angle_web/controllers/upload_controller_test.exs`
Expected: FAIL — controller/routes not found.

**Step 3: Implement the upload controller**

Create `lib/angle_web/controllers/upload_controller.ex`:

```elixir
defmodule AngleWeb.UploadController do
  use AngleWeb, :controller

  alias Angle.Media.{Image, Processor, Storage}

  @max_item_images 10

  def create(conn, %{"file" => %Plug.Upload{} = upload, "owner_type" => owner_type_str, "owner_id" => owner_id}) do
    user = conn.assigns.current_user
    owner_type = parse_owner_type(owner_type_str)

    with {:ok, owner_type} <- validate_owner_type(owner_type),
         :ok <- verify_ownership(user, owner_type, owner_id),
         :ok <- Processor.validate_file(upload.path, upload.content_type),
         :ok <- Processor.validate_file_size(file_size(upload.path)),
         :ok <- check_image_limit(owner_type, owner_id),
         {:ok, result} <- Processor.generate_variants(upload.path) do
      position = next_position(owner_type, owner_id)
      prefix = storage_prefix(owner_type, owner_id)

      # Handle single-image types (avatar, logo) — replace existing
      maybe_replace_existing(user, owner_type, owner_id)

      # Upload original + variants to R2
      original_key = "#{prefix}/original.webp"
      variant_keys = upload_all(upload.path, result, prefix, original_key)

      # Clean up temp files
      Processor.cleanup(result)

      # Create DB record
      {:ok, image} =
        Image
        |> Ash.Changeset.for_create(:create, %{
          owner_type: owner_type,
          owner_id: owner_id,
          storage_key: original_key,
          variants: variant_keys,
          position: position,
          file_size: file_size(upload.path),
          mime_type: upload.content_type,
          width: result.original_width,
          height: result.original_height
        }, actor: user)
        |> Ash.create()

      conn
      |> put_status(:created)
      |> json(%{
        id: image.id,
        storageKey: image.storage_key,
        variants: image.variants,
        position: image.position,
        width: image.width,
        height: image.height
      })
    else
      {:error, :invalid_type} ->
        conn |> put_status(422) |> json(%{error: "Only JPEG, PNG, and WebP images are accepted"})

      {:error, :file_too_large} ->
        conn |> put_status(413) |> json(%{error: "Image must be under 10MB"})

      {:error, :too_many_images} ->
        conn |> put_status(422) |> json(%{error: "Maximum #{@max_item_images} images per listing"})

      {:error, :not_authorized} ->
        conn |> put_status(403) |> json(%{error: "You don't have permission to upload here"})

      {:error, reason} ->
        conn |> put_status(422) |> json(%{error: "Could not process this image. Try a different file.", detail: inspect(reason)})
    end
  end

  def delete(conn, %{"id" => image_id}) do
    user = conn.assigns.current_user

    with {:ok, image} <- load_image(image_id),
         :ok <- verify_image_ownership(user, image) do
      # Delete from R2
      Storage.delete(image.storage_key)
      for {_name, key} <- image.variants, do: Storage.delete(key)

      # Delete DB record
      image
      |> Ash.Changeset.for_destroy(:destroy, %{}, actor: user)
      |> Ash.destroy!()

      send_resp(conn, 204, "")
    else
      {:error, :not_found} ->
        conn |> put_status(404) |> json(%{error: "Image not found"})

      {:error, :not_authorized} ->
        conn |> put_status(403) |> json(%{error: "You don't have permission to delete this image"})
    end
  end

  def reorder(conn, %{"item_id" => item_id, "image_ids" => image_ids}) do
    user = conn.assigns.current_user

    with :ok <- verify_ownership(user, :item, item_id) do
      images =
        image_ids
        |> Enum.with_index()
        |> Enum.map(fn {id, position} ->
          {:ok, image} =
            Image
            |> Ash.get!(id, actor: user)
            |> Ash.Changeset.for_update(:reorder, %{position: position}, actor: user)
            |> Ash.update()

          %{id: image.id, position: image.position, variants: image.variants}
        end)

      json(conn, %{images: images})
    else
      {:error, :not_authorized} ->
        conn |> put_status(403) |> json(%{error: "You don't have permission to reorder these images"})
    end
  end

  # --- Private helpers ---

  defp parse_owner_type("item"), do: :item
  defp parse_owner_type("user_avatar"), do: :user_avatar
  defp parse_owner_type("store_logo"), do: :store_logo
  defp parse_owner_type(_), do: :invalid

  defp validate_owner_type(:invalid), do: {:error, :invalid_type}
  defp validate_owner_type(type), do: {:ok, type}

  defp verify_ownership(user, :item, item_id) do
    case Ash.get(Angle.Inventory.Item, item_id, authorize?: false) do
      {:ok, item} ->
        if item.created_by_id == user.id, do: :ok, else: {:error, :not_authorized}

      _ ->
        {:error, :not_authorized}
    end
  end

  defp verify_ownership(user, :user_avatar, owner_id) do
    if user.id == owner_id, do: :ok, else: {:error, :not_authorized}
  end

  defp verify_ownership(user, :store_logo, store_profile_id) do
    case Ash.get(Angle.Accounts.StoreProfile, store_profile_id, authorize?: false) do
      {:ok, profile} ->
        if profile.user_id == user.id, do: :ok, else: {:error, :not_authorized}

      _ ->
        {:error, :not_authorized}
    end
  end

  defp verify_image_ownership(user, image) do
    verify_ownership(user, image.owner_type, image.owner_id)
  end

  defp load_image(id) do
    case Ash.get(Image, id, authorize?: false) do
      {:ok, image} -> {:ok, image}
      _ -> {:error, :not_found}
    end
  end

  defp check_image_limit(:item, owner_id) do
    count =
      Image
      |> Ash.Query.for_read(:by_owner, %{owner_type: :item, owner_id: owner_id}, authorize?: false)
      |> Ash.read!()
      |> length()

    if count >= @max_item_images, do: {:error, :too_many_images}, else: :ok
  end

  defp check_image_limit(_owner_type, _owner_id), do: :ok

  defp next_position(owner_type, owner_id) do
    Image
    |> Ash.Query.for_read(:by_owner, %{owner_type: owner_type, owner_id: owner_id}, authorize?: false)
    |> Ash.read!()
    |> Enum.map(& &1.position)
    |> case do
      [] -> 0
      positions -> Enum.max(positions) + 1
    end
  end

  defp maybe_replace_existing(user, type, owner_id) when type in [:user_avatar, :store_logo] do
    Image
    |> Ash.Query.for_read(:by_owner, %{owner_type: type, owner_id: owner_id}, authorize?: false)
    |> Ash.read!()
    |> Enum.each(fn image ->
      Storage.delete(image.storage_key)
      for {_name, key} <- image.variants, do: Storage.delete(key)

      image
      |> Ash.Changeset.for_destroy(:destroy, %{}, actor: user)
      |> Ash.destroy!()
    end)
  end

  defp maybe_replace_existing(_user, _type, _owner_id), do: :ok

  defp storage_prefix(:item, owner_id), do: "items/#{owner_id}/#{Ash.UUID.generate()}"
  defp storage_prefix(:user_avatar, owner_id), do: "avatars/#{owner_id}"
  defp storage_prefix(:store_logo, owner_id), do: "logos/#{owner_id}"

  defp upload_all(_original_path, result, prefix, _original_key) do
    variant_keys =
      for {name, path} <- result,
          name in [:thumbnail, :medium, :full],
          into: %{} do
        key = "#{prefix}/#{name}.webp"
        Storage.upload(path, key, "image/webp")
        {Atom.to_string(name), key}
      end

    variant_keys
  end

  defp file_size(path) do
    case File.stat(path) do
      {:ok, %{size: size}} -> size
      _ -> 0
    end
  end
end
```

**Step 4: Add routes**

In `lib/angle_web/router.ex`, add inside the authenticated scope (the one with `[:browser, :require_auth]` pipeline):

```elixir
post "/uploads", UploadController, :create
delete "/uploads/:id", UploadController, :delete
patch "/uploads/reorder", UploadController, :reorder
```

**Step 5: Run tests**

Run: `mix test test/angle_web/controllers/upload_controller_test.exs`
Expected: All tests pass.

**Step 6: Run full test suite**

Run: `mix test`
Expected: All tests pass.

**Step 7: Commit**

```bash
git add lib/angle_web/controllers/upload_controller.ex lib/angle_web/router.ex test/angle_web/controllers/upload_controller_test.exs
git commit -m "feat: add upload controller with create, delete, reorder endpoints"
```

---

## Task 6: TypeScript Codegen, Image URL Helper, and ResponsiveImage Component

**Files:**
- Regenerate: `assets/js/ash_rpc.ts`
- Create: `assets/js/lib/image-url.ts`
- Create: `assets/js/components/image-upload/responsive-image.tsx`

**Step 1: Regenerate TypeScript types**

Run: `mix ash_typescript.codegen`
Expected: `assets/js/ash_rpc.ts` updated with `Image` type.

**Step 2: Create image URL helper**

Create `assets/js/lib/image-url.ts`:

```typescript
const IMAGE_BASE_URL = import.meta.env.VITE_IMAGE_BASE_URL || "";

export type ImageVariant = "thumbnail" | "medium" | "full";

/** Variant max widths — must match server-side Processor config */
export const VARIANT_WIDTHS: Record<ImageVariant, number> = {
  thumbnail: 200,
  medium: 600,
  full: 1200,
};

export interface ImageData {
  id: string;
  variants: Record<string, string>;
  position: number;
  width: number;
  height: number;
}

/**
 * Constructs a full URL for an image variant.
 */
export function imageUrl(image: ImageData, variant: ImageVariant = "medium"): string {
  const key = image.variants[variant];
  if (!key) return "";
  return `${IMAGE_BASE_URL}/${key}`;
}

/**
 * Returns the cover image (position 0) from an array of images,
 * or null if no images exist.
 */
export function coverImage(images: ImageData[]): ImageData | null {
  if (!images || images.length === 0) return null;
  return images.find((img) => img.position === 0) || images[0];
}
```

**Step 3: Create ResponsiveImage component**

Create `assets/js/components/image-upload/responsive-image.tsx`:

```tsx
import { cn } from "@/lib/utils";
import { imageUrl, VARIANT_WIDTHS, type ImageData } from "@/lib/image-url";

interface ResponsiveImageProps {
  image: ImageData;
  sizes: string;
  alt?: string;
  className?: string;
  loading?: "lazy" | "eager";
}

/**
 * Renders an <img> with srcSet for all 3 variants (200w, 600w, 1200w).
 * The browser picks the best variant based on rendered size and device pixel ratio.
 *
 * Usage:
 *   <ResponsiveImage image={coverImage} sizes="(max-width: 640px) 85vw, 432px" />
 *
 * The `sizes` prop tells the browser how wide the image will render at each breakpoint,
 * so it can pick thumbnail (200w) for small renders or full (1200w) for large/retina.
 */
export function ResponsiveImage({
  image,
  sizes,
  alt = "",
  className,
  loading = "lazy",
}: ResponsiveImageProps) {
  const srcSet = (["thumbnail", "medium", "full"] as const)
    .filter((v) => image.variants[v])
    .map((v) => `${imageUrl(image, v)} ${VARIANT_WIDTHS[v]}w`)
    .join(", ");

  return (
    <img
      src={imageUrl(image, "medium")}
      srcSet={srcSet}
      sizes={sizes}
      alt={alt}
      className={cn("h-full w-full object-cover", className)}
      loading={loading}
    />
  );
}
```

The `sizes` prop is a standard HTML `sizes` attribute that describes how wide the image renders at each viewport breakpoint. Common patterns:

| Context | `sizes` value |
|---------|---------------|
| Item card (`w-[85vw] sm:w-[320px] lg:w-[432px]`) | `"(max-width: 640px) 85vw, (max-width: 1024px) 320px, 432px"` |
| Item detail gallery (full width mobile, half desktop) | `"(max-width: 768px) 100vw, 50vw"` |
| Avatar in nav (36px) | `"36px"` |
| Avatar in settings (96px) | `"96px"` |
| Store logo (64px in header) | `"64px"` |

For small fixed-size renders (avatars, logos), the browser will pick `thumbnail` (200w) which covers up to 100px even on 2x retina. For large renders (detail gallery), it will pick `full` (1200w).

**Step 4: Commit**

```bash
git add assets/js/ash_rpc.ts assets/js/lib/image-url.ts assets/js/components/image-upload/responsive-image.tsx
git commit -m "feat: add image URL helper, ResponsiveImage component, and regenerate TypeScript types"
```

---

## Task 7: Shared ImageUploader Component

**Files:**
- Create: `assets/js/components/image-upload/image-uploader.tsx`
- Create: `assets/js/components/image-upload/upload-preview.tsx`
- Create: `assets/js/components/image-upload/index.ts`

**Step 1: Create the upload preview component**

Create `assets/js/components/image-upload/upload-preview.tsx`:

```tsx
import { X, Loader2 } from "lucide-react";
import { cn } from "@/lib/utils";

interface UploadPreviewProps {
  src: string;
  isUploading?: boolean;
  progress?: number;
  onRemove?: () => void;
  className?: string;
}

export function UploadPreview({
  src,
  isUploading,
  progress,
  onRemove,
  className,
}: UploadPreviewProps) {
  return (
    <div className={cn("group relative overflow-hidden rounded-lg", className)}>
      <img
        src={src}
        alt=""
        className={cn(
          "h-full w-full object-cover",
          isUploading && "opacity-50"
        )}
      />

      {isUploading && (
        <div className="absolute inset-0 flex items-center justify-center bg-black/30">
          <Loader2 className="size-6 animate-spin text-white" />
          {progress !== undefined && (
            <span className="absolute bottom-2 text-xs font-medium text-white">
              {Math.round(progress)}%
            </span>
          )}
        </div>
      )}

      {!isUploading && onRemove && (
        <button
          type="button"
          onClick={onRemove}
          className="absolute right-1 top-1 flex size-6 items-center justify-center rounded-full bg-black/60 text-white opacity-0 transition-opacity group-hover:opacity-100"
        >
          <X className="size-3.5" />
        </button>
      )}
    </div>
  );
}
```

**Step 2: Create the main uploader component**

Create `assets/js/components/image-upload/image-uploader.tsx`:

```tsx
import { useCallback, useRef, useState } from "react";
import { Upload, ImagePlus } from "lucide-react";
import { cn } from "@/lib/utils";
import { UploadPreview } from "./upload-preview";
import { buildCSRFHeaders } from "@/lib/csrf";
import type { ImageData } from "@/lib/image-url";

interface UploadingFile {
  id: string;
  file: File;
  preview: string;
  progress: number;
}

interface ImageUploaderProps {
  ownerType: "item" | "user_avatar" | "store_logo";
  ownerId: string;
  images: ImageData[];
  onImagesChange: (images: ImageData[]) => void;
  multiple?: boolean;
  maxImages?: number;
  className?: string;
}

export function ImageUploader({
  ownerType,
  ownerId,
  images,
  onImagesChange,
  multiple = false,
  maxImages = 10,
  className,
}: ImageUploaderProps) {
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [uploading, setUploading] = useState<UploadingFile[]>([]);
  const [error, setError] = useState<string | null>(null);

  const canUpload = multiple ? images.length + uploading.length < maxImages : images.length === 0 && uploading.length === 0;

  const handleFiles = useCallback(
    async (files: FileList | File[]) => {
      setError(null);
      const fileArray = Array.from(files);

      if (!multiple && fileArray.length > 1) {
        fileArray.splice(1);
      }

      const remaining = maxImages - images.length - uploading.length;
      const toUpload = fileArray.slice(0, remaining);

      for (const file of toUpload) {
        const tempId = crypto.randomUUID();
        const preview = URL.createObjectURL(file);

        setUploading((prev) => [...prev, { id: tempId, file, preview, progress: 0 }]);

        try {
          const formData = new FormData();
          formData.append("file", file);
          formData.append("owner_type", ownerType);
          formData.append("owner_id", ownerId);

          const response = await fetch("/uploads", {
            method: "POST",
            headers: buildCSRFHeaders(),
            body: formData,
          });

          if (!response.ok) {
            const data = await response.json();
            throw new Error(data.error || "Upload failed");
          }

          const data = await response.json();

          // For single-image types, replace the existing image
          if (!multiple) {
            onImagesChange([data as ImageData]);
          } else {
            onImagesChange([...images, data as ImageData]);
          }
        } catch (err) {
          setError(err instanceof Error ? err.message : "Upload failed. Please try again.");
        } finally {
          URL.revokeObjectURL(preview);
          setUploading((prev) => prev.filter((u) => u.id !== tempId));
        }
      }
    },
    [ownerType, ownerId, images, uploading.length, multiple, maxImages, onImagesChange]
  );

  const handleRemove = useCallback(
    async (imageId: string) => {
      try {
        const response = await fetch(`/uploads/${imageId}`, {
          method: "DELETE",
          headers: {
            ...buildCSRFHeaders(),
          },
        });

        if (response.ok) {
          onImagesChange(images.filter((img) => img.id !== imageId));
        }
      } catch {
        setError("Failed to delete image. Please try again.");
      }
    },
    [images, onImagesChange]
  );

  const handleDrop = useCallback(
    (e: React.DragEvent) => {
      e.preventDefault();
      if (canUpload && e.dataTransfer.files.length > 0) {
        handleFiles(e.dataTransfer.files);
      }
    },
    [canUpload, handleFiles]
  );

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault();
  };

  return (
    <div className={className}>
      {error && (
        <p className="mb-2 text-sm text-feedback-error">{error}</p>
      )}

      <div className={cn(
        "grid gap-2",
        multiple ? "grid-cols-3 sm:grid-cols-4 lg:grid-cols-5" : "grid-cols-1"
      )}>
        {/* Existing images */}
        {images.map((image) => (
          <UploadPreview
            key={image.id}
            src={`${import.meta.env.VITE_IMAGE_BASE_URL || ""}/${image.variants.thumbnail || image.variants.medium}`}
            onRemove={() => handleRemove(image.id)}
            className={multiple ? "aspect-square" : "aspect-square max-w-[160px]"}
          />
        ))}

        {/* Uploading previews */}
        {uploading.map((u) => (
          <UploadPreview
            key={u.id}
            src={u.preview}
            isUploading
            progress={u.progress}
            className={multiple ? "aspect-square" : "aspect-square max-w-[160px]"}
          />
        ))}

        {/* Drop zone / add button */}
        {canUpload && (
          <button
            type="button"
            onClick={() => fileInputRef.current?.click()}
            onDrop={handleDrop}
            onDragOver={handleDragOver}
            className={cn(
              "flex flex-col items-center justify-center rounded-lg border-2 border-dashed border-border-subtle bg-surface-muted text-content-placeholder transition-colors hover:border-primary-400 hover:text-primary-500",
              multiple ? "aspect-square" : "aspect-square max-w-[160px]"
            )}
          >
            {multiple ? (
              <ImagePlus className="size-6" />
            ) : (
              <Upload className="size-6" />
            )}
            <span className="mt-1 text-xs">
              {multiple ? "Add" : "Upload"}
            </span>
          </button>
        )}
      </div>

      <input
        ref={fileInputRef}
        type="file"
        accept="image/jpeg,image/png,image/webp"
        multiple={multiple}
        className="hidden"
        onChange={(e) => {
          if (e.target.files) handleFiles(e.target.files);
          e.target.value = "";
        }}
      />

      {multiple && (
        <p className="mt-1 text-xs text-content-placeholder">
          {images.length}/{maxImages} images
        </p>
      )}
    </div>
  );
}
```

**Step 3: Create barrel export**

Create `assets/js/components/image-upload/index.ts`:

```typescript
export { ImageUploader } from "./image-uploader";
export { UploadPreview } from "./upload-preview";
export { ResponsiveImage } from "./responsive-image";
```

**Step 4: Verify build**

Run: `mix assets.build`
Expected: Compiles with 0 errors.

**Step 5: Commit**

```bash
git add assets/js/components/image-upload/
git commit -m "feat: add shared ImageUploader component with drag-drop and preview"
```

---

## Task 8: Avatar Upload Integration

**Files:**
- Modify: `assets/js/features/settings/components/profile-image-section.tsx`
- Modify: `assets/js/features/settings/components/account-form.tsx`

**Step 1: Update ProfileImageSection to use ImageUploader**

Replace `assets/js/features/settings/components/profile-image-section.tsx` with a functional component that uses `ImageUploader` with `ownerType="user_avatar"` and `ownerId={userId}`. It should:
- Accept `userId: string` and initial `avatarImages: ImageData[]` props
- Show the current avatar using the `medium` variant if it exists, or the `User` icon placeholder
- Provide "Change" and "Remove" functionality via the `ImageUploader` component in single mode (`multiple={false}`)

**Step 2: Update AccountForm to pass avatar data**

The `AccountForm` component needs to receive and pass avatar image data to `ProfileImageSection`. The controller for the account settings page (`SettingsController` or equivalent) should load any existing avatar images for the user.

**Step 3: Verify build**

Run: `mix assets.build`
Expected: Compiles with 0 errors.

**Step 4: Browser test**

Navigate to Settings > Account. Verify:
- Avatar placeholder shows when no image exists
- Clicking "Upload" opens file picker
- After upload, avatar displays
- "Remove" button deletes the avatar

**Step 5: Commit**

```bash
git add assets/js/features/settings/components/profile-image-section.tsx assets/js/features/settings/components/account-form.tsx
git commit -m "feat: integrate avatar upload in account settings"
```

---

## Task 9: Store Logo Upload Integration

**Files:**
- Modify: `assets/js/features/settings/components/store-logo-section.tsx`
- Modify: `assets/js/features/settings/components/store-form.tsx`

**Step 1: Update StoreLogoSection to use ImageUploader**

Replace `assets/js/features/settings/components/store-logo-section.tsx` with a functional component that uses `ImageUploader` with `ownerType="store_logo"` and `ownerId={storeProfileId}`. Pattern matches Task 8 but for store logos.

**Step 2: Update StoreForm to pass logo data**

The `StoreForm` needs the `storeProfileId` and existing logo images. The settings store controller should load existing logo images.

**Step 3: Verify build and browser test**

Run: `mix assets.build`
Navigate to Settings > Store. Verify logo upload/remove works.

**Step 4: Commit**

```bash
git add assets/js/features/settings/components/store-logo-section.tsx assets/js/features/settings/components/store-form.tsx
git commit -m "feat: integrate store logo upload in store settings"
```

---

## Task 10: Item Image Manager

**Files:**
- Create: `assets/js/components/image-upload/item-image-manager.tsx`
- Modify: `assets/js/features/items/components/item-form.tsx`

**Step 1: Create ItemImageManager**

Create `assets/js/components/image-upload/item-image-manager.tsx` — a multi-image upload component for item create/edit forms:
- Uses `ImageUploader` with `ownerType="item"`, `multiple={true}`, `maxImages={10}`
- Drag-to-reorder support (call `PATCH /uploads/reorder` on order change)
- First image (position 0) marked as "Cover"
- Grid layout matching the item form design

**Step 2: Integrate into ItemForm**

Modify `assets/js/features/items/components/item-form.tsx`:
- Add `ItemImageManager` above the form fields
- For edit mode, load existing item images from the controller
- For create mode, allow uploading images after initial item creation (may need to save draft first)

**Step 3: Verify build and browser test**

Run: `mix assets.build`
Test creating an item with images. Test editing an item to add/remove/reorder images.

**Step 4: Commit**

```bash
git add assets/js/components/image-upload/item-image-manager.tsx assets/js/features/items/components/item-form.tsx
git commit -m "feat: add multi-image upload to item form with reorder"
```

---

## Task 11: Display Images in Item Cards and Detail Pages

**Files:**
- Modify: `assets/js/features/items/components/item-card.tsx`
- Modify: various item card components that show Gavel placeholder
- Modify: item detail page to show image gallery

This task replaces all Gavel/placeholder icons with actual images.

**Step 1: Add image fields to item typed queries**

In `lib/angle/media.ex`, add a typed query for loading images by owner. Alternatively, if items have a relationship to images, add image fields to existing item typed queries in `lib/angle/inventory.ex`.

Since the Image resource uses a polymorphic `owner_id` (not a proper foreign key relationship), the approach is:
- Add a typed query in `Angle.Media` domain: `:images_by_owner` that takes `owner_type` and `owner_id`
- On the frontend, item cards can include image data loaded by the controller
- Controllers that load items should also load their cover images

**Step 2: Update controllers to load item images**

Modify controllers (ItemsController, StoreController, HomepageController, etc.) to also load cover images for items being displayed. This can be done as a separate query:

```elixir
defp load_cover_images(item_ids) do
  Angle.Media.Image
  |> Ash.Query.for_read(:read, %{}, authorize?: false)
  |> Ash.Query.filter(owner_type == :item and owner_id in ^item_ids and position == 0)
  |> Ash.read!()
  |> Map.new(fn image -> {image.owner_id, image} end)
end
```

Then merge into item data before passing as props.

**Step 3: Update ItemCard component**

In `assets/js/features/items/components/item-card.tsx`:
- Accept optional `coverImage` prop (or check if item has an `images` field)
- If cover image exists, use `ResponsiveImage` with appropriate `sizes`
- If no image, keep the Gavel placeholder as fallback

```tsx
import { ResponsiveImage } from "@/components/image-upload";

// Inside the image area div:
{item.coverImage ? (
  <ResponsiveImage
    image={item.coverImage}
    sizes="(max-width: 640px) 85vw, (max-width: 1024px) 320px, 432px"
    alt={item.title}
  />
) : (
  <div className="flex h-full items-center justify-center text-content-placeholder">
    <Gavel className="size-12 lg:size-16" />
  </div>
)}
```

The `sizes` value matches the card's responsive widths (`w-[85vw] sm:w-[320px] lg:w-[432px]`), so the browser picks `thumbnail` on small screens and `medium` or `full` on larger/retina displays.

**Step 4: Update item detail page with gallery**

Create or modify the item detail page to show:
- Main image viewer using `ResponsiveImage` with `sizes="(max-width: 768px) 100vw, 50vw"` — picks `full` variant on desktop/retina
- Thumbnail strip below using `imageUrl(image, "thumbnail")` directly (fixed small size, no srcSet needed)
- Click thumbnail to switch main image

**Step 5: Update other card variants**

Repeat the `ResponsiveImage` pattern for each card, with `sizes` matching each card's CSS widths:
- `category-item-card.tsx` — `sizes` per its responsive breakpoints
- `category-item-list-card.tsx` — `sizes` per its layout
- `featured-item-carousel` cards — `sizes` per carousel card width
- Watchlist cards
- Won bids cards

**Step 6: Verify build and browser test**

Run: `mix assets.build`
Browse through the app checking:
- Homepage item cards show images (or Gavel fallback)
- Item detail page shows gallery
- Store page item cards show images
- Watchlist cards show images

**Step 7: Commit**

```bash
git add -A
git commit -m "feat: display item images in cards and detail pages"
```

---

## Task 12: Display Avatar and Logo in Navigation and Store Pages

**Files:**
- Modify: `assets/js/navigation/user-menu-popover.tsx` (avatar in nav)
- Modify: `assets/js/features/store-dashboard/components/profile-header.tsx` (store logo)
- Modify: `assets/js/pages/store/show.tsx` (public store page logo)

**Step 1: Update shared props to include avatar URL**

In the Inertia shared props configuration (the `assign_prop` plug), add the current user's avatar thumbnail URL if one exists. This avoids loading avatar data on every page individually.

**Step 2: Update user menu popover**

In `assets/js/navigation/user-menu-popover.tsx`:
- If user has avatar URL in shared props, use `ResponsiveImage` with `sizes="36px"` (nav avatar is ~36px, browser will pick `thumbnail` 200w — crisp even on 3x retina)
- Otherwise keep `User` icon placeholder

**Step 3: Update store profile pages**

- Store dashboard header: show logo with `ResponsiveImage` using `sizes="64px"` if logo exists
- Public store page: show logo with `ResponsiveImage` using `sizes="(max-width: 768px) 80px, 96px"` if exists

**Step 4: Verify build and browser test**

Run: `mix assets.build`
Check nav menu avatar, store dashboard logo, public store page logo.

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: display avatar and store logo in navigation and store pages"
```

---

## Summary

| Task | Description | Dependencies |
|------|-------------|-------------|
| 1 | Add deps (image, ex_aws, ex_aws_s3, sweet_xml) | None |
| 2 | Media domain + Image resource + migration | Task 1 |
| 3 | Image processor (libvips variants) | Task 1 |
| 4 | R2 storage module (behaviour + mock) | Task 1 |
| 5 | Upload controller + routes + tests | Tasks 2, 3, 4 |
| 6 | TypeScript codegen + image URL helper + ResponsiveImage | Task 2 |
| 7 | Shared ImageUploader component | Task 6 |
| 8 | Avatar upload in account settings | Tasks 5, 7 |
| 9 | Store logo upload in store settings | Tasks 5, 7 |
| 10 | Item image manager (multi-upload + reorder) | Tasks 5, 7 |
| 11 | Display images in item cards + detail pages | Tasks 6, 10 |
| 12 | Display avatar + logo in nav + store pages | Tasks 8, 9 |
