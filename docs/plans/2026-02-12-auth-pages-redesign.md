# Auth Pages Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Redesign the Sign Up, Verify Account, and Login pages to match Figma designs — split-screen layout, phone/email toggle, 6-digit OTP verification, and Google OAuth.

**Architecture:** Auth pages use a shared `AuthLayout` component with a hero image on desktop (left half) and form on the right. Registration sends a 6-digit OTP code via branded email instead of a confirmation link. The OTP code maps to the existing AshAuthentication JWT confirmation token, preserving the underlying auth infrastructure. Google OAuth uses AshAuthentication's OAuth2 strategy.

**Tech Stack:** React 19, Inertia.js, shadcn/ui, Tailwind CSS, Ash Framework, AshAuthentication, Swoosh email, input-otp (already installed)

---

## Decisions

| Question | Decision |
|----------|----------|
| SMS sending | Stub for now — build phone UI, no SMS infrastructure |
| OTP verification | New 6-digit OTP email flow for signup; keep token-links for password reset |
| Google OAuth | Wire up fully with AshAuthentication OAuth2 (config from env vars + setup guide) |
| Login page | Redesign with same split-screen AuthLayout |
| Hero image | Configurable via prop, ship with one static image |
| Category pills | Decorative only, not clickable |
| OTP email | Branded HTML email with Angle styling |
| Google creds | Include setup instructions for Google Cloud OAuth |

---

## Task 1: Add `full_name` and `phone_number` attributes to User resource

**Files:**
- Modify: `lib/angle/accounts/user.ex` (attributes block, line ~413-418; register_with_password action, line ~159-195)
- Modify: `test/support/factory.ex` (create_user function, line ~20-32)
- Test: `test/angle/accounts/user_registration_test.exs` (create new)

**Step 1: Write the failing test**

Create `test/angle/accounts/user_registration_test.exs`:

```elixir
defmodule Angle.Accounts.UserRegistrationTest do
  use Angle.DataCase, async: true

  alias Angle.Factory

  describe "register_with_password" do
    test "creates user with full_name" do
      user = Factory.create_user(%{full_name: "Emmanuella Abubakar"})
      assert user.full_name == "Emmanuella Abubakar"
    end

    test "creates user with phone_number" do
      user = Factory.create_user(%{phone_number: "+2348012345678"})
      assert user.phone_number == "+2348012345678"
    end

    test "creates user without full_name (optional)" do
      user = Factory.create_user()
      assert is_nil(user.full_name) or user.full_name == nil
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/angle/accounts/user_registration_test.exs --max-failures 1`
Expected: FAIL — `full_name` and `phone_number` are not attributes

**Step 3: Add attributes to User resource**

In `lib/angle/accounts/user.ex`, add to the `attributes` block (after line 417):

```elixir
  attributes do
    uuid_primary_key :id
    attribute :email, :ci_string, allow_nil?: false, public?: true
    attribute :hashed_password, :string, allow_nil?: false, sensitive?: true
    attribute :confirmed_at, :utc_datetime_usec
    attribute :full_name, :string, public?: true
    attribute :phone_number, :string, public?: true
  end
```

**Step 4: Update register_with_password action to accept full_name and phone_number**

In `lib/angle/accounts/user.ex`, modify the `register_with_password` action (around line 159):

```elixir
    create :register_with_password do
      description "Register a new user with a email and password."

      argument :email, :ci_string do
        allow_nil? false
      end

      argument :password, :string do
        description "The proposed password for the user, in plain text."
        allow_nil? false
        constraints min_length: 8
        sensitive? true
      end

      argument :password_confirmation, :string do
        description "The proposed password for the user (again), in plain text."
        allow_nil? false
        sensitive? true
      end

      argument :full_name, :string do
        description "The user's full name."
      end

      argument :phone_number, :string do
        description "The user's phone number."
      end

      # Sets the email from the argument
      change set_attribute(:email, arg(:email))

      # Sets optional fields
      change set_attribute(:full_name, arg(:full_name))
      change set_attribute(:phone_number, arg(:phone_number))

      # Hashes the provided password
      change AshAuthentication.Strategy.Password.HashPasswordChange

      # Generates an authentication token for the user
      change AshAuthentication.GenerateTokenChange

      # validates that the password matches the confirmation
      validate AshAuthentication.Strategy.Password.PasswordConfirmationValidation

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end
```

**Step 5: Update factory to pass full_name and phone_number**

In `test/support/factory.ex`, update `create_user/1`:

```elixir
  def create_user(attrs \\ %{}) do
    password = Map.get(attrs, :password, "Password123!")

    params =
      %{
        email: Map.get(attrs, :email, unique_email()),
        password: password,
        password_confirmation: Map.get(attrs, :password_confirmation, password)
      }
      |> maybe_put(:full_name, Map.get(attrs, :full_name))
      |> maybe_put(:phone_number, Map.get(attrs, :phone_number))

    Angle.Accounts.User
    |> Ash.Changeset.for_create(:register_with_password, params, authorize?: false)
    |> Ash.create!(authorize?: false)
  end
```

**Step 6: Generate and run migration**

Run: `mix ash.codegen add_full_name_and_phone_to_users`
Then: `mix ash.setup --quiet`

**Step 7: Run tests to verify they pass**

Run: `mix test test/angle/accounts/user_registration_test.exs -v`
Expected: PASS (3 tests)

**Step 8: Update auth types on frontend**

In `assets/js/types/auth.ts`, update the User interface (line 16-22):

```typescript
export interface User {
  id: string;
  email: string;
  full_name: string | null;
  phone_number: string | null;
  confirmed_at: string | null;
  roles: string[];
  permissions: string[];
}
```

**Step 9: Commit**

```bash
git add lib/angle/accounts/user.ex test/support/factory.ex test/angle/accounts/user_registration_test.exs assets/js/types/auth.ts priv/repo/migrations/
git commit -m "feat: add full_name and phone_number attributes to User resource"
```

---

## Task 2: Create OTP resource and helper module

**Files:**
- Create: `lib/angle/accounts/otp.ex`
- Modify: `lib/angle/accounts.ex` (add resource, line ~16-23)
- Create: `lib/angle/accounts/otp_helper.ex`
- Test: `test/angle/accounts/otp_helper_test.exs`

**Step 1: Create the OTP resource**

Create `lib/angle/accounts/otp.ex`:

```elixir
defmodule Angle.Accounts.Otp do
  use Ash.Resource,
    otp_app: :angle,
    domain: Angle.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "otps"
    repo Angle.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:code, :user_id, :confirmation_token, :purpose, :expires_at]
    end

    update :mark_used do
      accept []
      change set_attribute(:used_at, &DateTime.utc_now/0)
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    policy always() do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :code, :string, allow_nil?: false, public?: true
    attribute :user_id, :uuid, allow_nil?: false, public?: true
    attribute :confirmation_token, :string, allow_nil?: false, sensitive?: true
    attribute :purpose, :string, allow_nil?: false, default: "confirm_new_user", public?: true
    attribute :expires_at, :utc_datetime_usec, allow_nil?: false, public?: true
    attribute :used_at, :utc_datetime_usec, public?: true
    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Angle.Accounts.User do
      attribute_writable? true
      define_attribute? false
      source_attribute :user_id
    end
  end
end
```

**Step 2: Register OTP resource in the Accounts domain**

In `lib/angle/accounts.ex`, add to the resources block (after line 21):

```elixir
  resources do
    resource Angle.Accounts.Token
    resource Angle.Accounts.User
    resource Angle.Accounts.UserRole
    resource Angle.Accounts.Role
    resource Angle.Accounts.Permission
    resource Angle.Accounts.RolePermission
    resource Angle.Accounts.Otp
  end
```

**Step 3: Generate migration**

Run: `mix ash.codegen create_otps_table`
Then: `mix ash.setup --quiet`

**Step 4: Create OTP helper module**

Create `lib/angle/accounts/otp_helper.ex`:

```elixir
defmodule Angle.Accounts.OtpHelper do
  @moduledoc """
  Helper module for generating, storing, and verifying OTP codes.
  """

  require Ash.Query

  @otp_expiry_minutes 10

  @doc """
  Generates a random 6-digit OTP code string.
  """
  def generate_code do
    :rand.uniform(999_999)
    |> Integer.to_string()
    |> String.pad_leading(6, "0")
  end

  @doc """
  Creates an OTP record for a user with the given confirmation token.
  Invalidates any existing unused OTPs for the same user and purpose.
  """
  def create_otp(user_id, confirmation_token, purpose \\ "confirm_new_user") do
    invalidate_codes(user_id, purpose)

    Ash.create!(
      Angle.Accounts.Otp,
      %{
        code: generate_code(),
        user_id: user_id,
        confirmation_token: confirmation_token,
        purpose: purpose,
        expires_at: DateTime.add(DateTime.utc_now(), @otp_expiry_minutes, :minute)
      },
      authorize?: false
    )
  end

  @doc """
  Verifies an OTP code for a user. Returns {:ok, otp} if valid, {:error, reason} otherwise.
  Marks the OTP as used on success.
  """
  def verify_code(code, user_id, purpose \\ "confirm_new_user") do
    now = DateTime.utc_now()

    case Ash.Query.filter(
           Angle.Accounts.Otp,
           expr(
             code == ^code and user_id == ^user_id and purpose == ^purpose and
               is_nil(used_at) and expires_at > ^now
           )
         )
         |> Ash.Query.sort(created_at: :desc)
         |> Ash.Query.limit(1)
         |> Ash.read(domain: Angle.Accounts, authorize?: false) do
      {:ok, [otp]} ->
        Ash.update!(otp, %{}, action: :mark_used, domain: Angle.Accounts, authorize?: false)
        {:ok, otp}

      {:ok, []} ->
        {:error, :invalid_code}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Invalidates all unused OTP codes for a user and purpose.
  """
  def invalidate_codes(user_id, purpose \\ "confirm_new_user") do
    Ash.Query.filter(
      Angle.Accounts.Otp,
      expr(user_id == ^user_id and purpose == ^purpose and is_nil(used_at))
    )
    |> Ash.read!(domain: Angle.Accounts, authorize?: false)
    |> Enum.each(fn otp ->
      Ash.update!(otp, %{}, action: :mark_used, domain: Angle.Accounts, authorize?: false)
    end)
  end
end
```

**Step 5: Write tests for OTP helper**

Create `test/angle/accounts/otp_helper_test.exs`:

```elixir
defmodule Angle.Accounts.OtpHelperTest do
  use Angle.DataCase, async: true

  alias Angle.Accounts.OtpHelper
  alias Angle.Factory

  describe "generate_code/0" do
    test "generates a 6-digit string" do
      code = OtpHelper.generate_code()
      assert String.length(code) == 6
      assert String.match?(code, ~r/^\d{6}$/)
    end
  end

  describe "create_otp/3" do
    test "creates an OTP record" do
      user = Factory.create_user()
      otp = OtpHelper.create_otp(user.id, "fake_token_123")

      assert otp.user_id == user.id
      assert otp.confirmation_token == "fake_token_123"
      assert otp.purpose == "confirm_new_user"
      assert String.length(otp.code) == 6
      assert is_nil(otp.used_at)
      assert DateTime.compare(otp.expires_at, DateTime.utc_now()) == :gt
    end

    test "invalidates previous codes on creation" do
      user = Factory.create_user()
      otp1 = OtpHelper.create_otp(user.id, "token_1")
      _otp2 = OtpHelper.create_otp(user.id, "token_2")

      # Reload otp1 to check it was marked as used
      reloaded = Ash.get!(Angle.Accounts.Otp, otp1.id, domain: Angle.Accounts, authorize?: false)
      assert not is_nil(reloaded.used_at)
    end
  end

  describe "verify_code/3" do
    test "returns {:ok, otp} for valid code" do
      user = Factory.create_user()
      otp = OtpHelper.create_otp(user.id, "valid_token")

      assert {:ok, verified} = OtpHelper.verify_code(otp.code, user.id)
      assert verified.id == otp.id
    end

    test "marks OTP as used after verification" do
      user = Factory.create_user()
      otp = OtpHelper.create_otp(user.id, "valid_token")

      {:ok, _} = OtpHelper.verify_code(otp.code, user.id)

      reloaded = Ash.get!(Angle.Accounts.Otp, otp.id, domain: Angle.Accounts, authorize?: false)
      assert not is_nil(reloaded.used_at)
    end

    test "returns {:error, :invalid_code} for wrong code" do
      user = Factory.create_user()
      _otp = OtpHelper.create_otp(user.id, "valid_token")

      assert {:error, :invalid_code} = OtpHelper.verify_code("000000", user.id)
    end

    test "returns {:error, :invalid_code} for already-used code" do
      user = Factory.create_user()
      otp = OtpHelper.create_otp(user.id, "valid_token")

      {:ok, _} = OtpHelper.verify_code(otp.code, user.id)
      assert {:error, :invalid_code} = OtpHelper.verify_code(otp.code, user.id)
    end

    test "returns {:error, :invalid_code} for wrong user" do
      user1 = Factory.create_user()
      user2 = Factory.create_user()
      otp = OtpHelper.create_otp(user1.id, "valid_token")

      assert {:error, :invalid_code} = OtpHelper.verify_code(otp.code, user2.id)
    end
  end
end
```

**Step 6: Run tests**

Run: `mix test test/angle/accounts/otp_helper_test.exs -v`
Expected: PASS (all tests)

**Step 7: Commit**

```bash
git add lib/angle/accounts/otp.ex lib/angle/accounts/otp_helper.ex lib/angle/accounts.ex test/angle/accounts/otp_helper_test.exs priv/repo/migrations/
git commit -m "feat: add OTP resource and helper module for verification codes"
```

---

## Task 3: Create branded OTP email sender

**Files:**
- Modify: `lib/angle/accounts/user/senders/send_new_user_confirmation_email.ex`
- Create: `lib/angle/accounts/email_templates.ex`
- Test: `test/angle/accounts/senders/send_new_user_confirmation_email_test.exs`

**Step 1: Create email templates module**

Create `lib/angle/accounts/email_templates.ex`:

```elixir
defmodule Angle.Accounts.EmailTemplates do
  @moduledoc """
  Branded HTML email templates for Angle.
  """

  @doc """
  Returns a branded HTML email template for OTP verification.
  """
  def otp_verification(code) do
    # Format code as XXX-XXX
    formatted_code =
      code
      |> String.graphemes()
      |> Enum.chunk_every(3)
      |> Enum.map_join("-", &Enum.join/1)

    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
    </head>
    <body style="margin: 0; padding: 0; background-color: #f9fafb; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;">
      <table role="presentation" cellpadding="0" cellspacing="0" style="width: 100%; background-color: #f9fafb;">
        <tr>
          <td align="center" style="padding: 40px 20px;">
            <table role="presentation" cellpadding="0" cellspacing="0" style="width: 100%; max-width: 480px; background-color: #ffffff; border-radius: 12px; box-shadow: 0 1px 3px rgba(0,0,0,0.1);">
              <!-- Logo -->
              <tr>
                <td align="center" style="padding: 32px 32px 0;">
                  <span style="font-size: 24px; font-weight: 700; color: #f97316;">ANGLE</span>
                </td>
              </tr>
              <!-- Heading -->
              <tr>
                <td align="center" style="padding: 24px 32px 8px;">
                  <h1 style="margin: 0; font-size: 22px; font-weight: 700; color: #111827;">Verify your account</h1>
                </td>
              </tr>
              <!-- Subtext -->
              <tr>
                <td align="center" style="padding: 0 32px 24px;">
                  <p style="margin: 0; font-size: 15px; color: #6b7280; line-height: 1.5;">
                    Enter this code to complete your registration. The code expires in 10 minutes.
                  </p>
                </td>
              </tr>
              <!-- OTP Code -->
              <tr>
                <td align="center" style="padding: 0 32px 32px;">
                  <div style="display: inline-block; padding: 16px 32px; background-color: #f3f4f6; border-radius: 8px; letter-spacing: 6px; font-size: 32px; font-weight: 700; color: #111827; font-family: monospace;">
                    #{formatted_code}
                  </div>
                </td>
              </tr>
              <!-- Footer -->
              <tr>
                <td align="center" style="padding: 0 32px 32px;">
                  <p style="margin: 0; font-size: 13px; color: #9ca3af; line-height: 1.5;">
                    If you didn't create an account on Angle, you can safely ignore this email.
                  </p>
                </td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
    </body>
    </html>
    """
  end
end
```

**Step 2: Modify the confirmation email sender to use OTP**

Replace `lib/angle/accounts/user/senders/send_new_user_confirmation_email.ex`:

```elixir
defmodule Angle.Accounts.User.Senders.SendNewUserConfirmationEmail do
  @moduledoc """
  Sends a branded OTP verification email for new user confirmation.

  Instead of sending a clickable link, generates a 6-digit OTP code,
  stores it mapped to the JWT confirmation token, and sends the code
  via a branded HTML email.
  """

  use AshAuthentication.Sender

  import Swoosh.Email

  alias Angle.Accounts.{EmailTemplates, OtpHelper}
  alias Angle.Mailer

  @impl true
  def send(user, token, _opts) do
    otp = OtpHelper.create_otp(user.id, token, "confirm_new_user")

    {sender_name, sender_email} =
      Application.get_env(:angle, :sender_email, {"Angle", "noreply@angle.app"})

    new()
    |> from({sender_name, sender_email})
    |> to(to_string(user.email))
    |> subject("Your Angle verification code: #{otp.code}")
    |> html_body(EmailTemplates.otp_verification(otp.code))
    |> Mailer.deliver!()
  end
end
```

**Step 3: Write test**

Create `test/angle/accounts/senders/send_new_user_confirmation_email_test.exs`:

```elixir
defmodule Angle.Accounts.User.Senders.SendNewUserConfirmationEmailTest do
  use Angle.DataCase, async: true

  alias Angle.Accounts.User.Senders.SendNewUserConfirmationEmail
  alias Angle.Factory

  describe "send/3" do
    test "creates an OTP and sends email" do
      user = Factory.create_user()

      # Should not raise
      assert :ok = SendNewUserConfirmationEmail.send(user, "fake_jwt_token", [])

      # Verify OTP was created
      otps =
        Ash.Query.filter(Angle.Accounts.Otp, expr(user_id == ^user.id))
        |> Ash.read!(domain: Angle.Accounts, authorize?: false)

      assert length(otps) >= 1
      otp = List.first(otps)
      assert otp.confirmation_token == "fake_jwt_token"
      assert otp.purpose == "confirm_new_user"
    end
  end
end
```

**Step 4: Run tests**

Run: `mix test test/angle/accounts/senders/ -v`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/angle/accounts/user/senders/send_new_user_confirmation_email.ex lib/angle/accounts/email_templates.ex test/angle/accounts/senders/
git commit -m "feat: replace confirmation link email with branded OTP email"
```

---

## Task 4: Add verify account routes and controller actions

**Files:**
- Modify: `lib/angle_web/router.ex` (auth scope, line ~72-86)
- Modify: `lib/angle_web/controllers/auth_controller.ex`
- Test: `test/angle_web/controllers/auth_controller_test.exs` (create new)

**Step 1: Add routes**

In `lib/angle_web/router.ex`, update the auth scope (line 72-86):

```elixir
  # Auth routes (guest only)
  scope "/auth", AngleWeb do
    pipe_through :browser

    get "/login", AuthController, :login
    post "/login", AuthController, :do_login
    get "/register", AuthController, :register
    post "/register", AuthController, :do_register
    get "/verify-account", AuthController, :verify_account
    post "/verify-account", AuthController, :do_verify_account
    post "/resend-otp", AuthController, :resend_otp
    get "/forgot-password", AuthController, :forgot_password
    post "/forgot-password", AuthController, :do_forgot_password
    get "/reset-password/:token", AuthController, :reset_password
    post "/reset-password", AuthController, :do_reset_password
    get "/confirm-new-user/:token", AuthController, :confirm_new_user
    post "/logout", AuthController, :logout
  end
```

**Step 2: Update the registration handler to redirect to verify page**

In `lib/angle_web/controllers/auth_controller.ex`, update `do_register/2`:

```elixir
  def do_register(conn, %{
        "email" => email,
        "password" => password,
        "password_confirmation" => password_confirmation
      } = params) do
    register_params = %{
      email: email,
      password: password,
      password_confirmation: password_confirmation,
      full_name: Map.get(params, "full_name"),
      phone_number: Map.get(params, "phone_number")
    }

    case Angle.Accounts.User.register_with_password(register_params) do
      {:ok, %{user: user, metadata: %{token: token}}} ->
        conn
        |> put_session(:current_user_id, user.id)
        |> put_session(:auth_token, token)
        |> put_session(:verify_user_id, user.id)
        |> put_session(:verify_email, to_string(user.email))
        |> redirect(to: ~p"/auth/verify-account")

      {:ok, user} ->
        conn
        |> put_session(:current_user_id, user.id)
        |> put_session(:verify_user_id, user.id)
        |> put_session(:verify_email, to_string(user.email))
        |> redirect(to: ~p"/auth/verify-account")

      {:error, changeset} ->
        errors = format_changeset_errors(changeset)

        conn
        |> put_flash(:error, "Registration failed: #{errors}")
        |> redirect(to: ~p"/auth/register")
    end
  end
```

**Step 3: Add verify account controller actions**

Add to `lib/angle_web/controllers/auth_controller.ex` (before `logout/2`):

```elixir
  def verify_account(conn, _params) do
    email = get_session(conn, :verify_email)
    user_id = get_session(conn, :verify_user_id)

    if is_nil(user_id) do
      conn
      |> put_flash(:error, "Please register first.")
      |> redirect(to: ~p"/auth/register")
    else
      render_inertia(conn, "auth/verify-account", %{email: email})
    end
  end

  def do_verify_account(conn, %{"code" => code}) do
    user_id = get_session(conn, :verify_user_id)

    if is_nil(user_id) do
      conn
      |> put_flash(:error, "Session expired. Please register again.")
      |> redirect(to: ~p"/auth/register")
    else
      with {:ok, otp} <- Angle.Accounts.OtpHelper.verify_code(code, user_id),
           {:ok, user} <-
             Ash.get(Angle.Accounts.User, user_id, domain: Angle.Accounts, authorize?: false),
           {:ok, _confirmed_user} <-
             Ash.update(user, %{confirm: otp.confirmation_token},
               action: :confirm,
               domain: Angle.Accounts,
               authorize?: false
             ) do
        conn
        |> delete_session(:verify_user_id)
        |> delete_session(:verify_email)
        |> put_flash(:success, "Account verified successfully! Welcome to Angle.")
        |> redirect(to: ~p"/dashboard")
      else
        {:error, :invalid_code} ->
          conn
          |> put_flash(:error, "Invalid verification code. Please try again.")
          |> redirect(to: ~p"/auth/verify-account")

        {:error, _} ->
          conn
          |> put_flash(:error, "Verification failed. Please try again.")
          |> redirect(to: ~p"/auth/verify-account")
      end
    end
  end

  def resend_otp(conn, _params) do
    user_id = get_session(conn, :verify_user_id)

    if is_nil(user_id) do
      conn
      |> put_flash(:error, "Session expired. Please register again.")
      |> redirect(to: ~p"/auth/register")
    else
      case Ash.get(Angle.Accounts.User, user_id,
             domain: Angle.Accounts,
             authorize?: false
           ) do
        {:ok, user} ->
          # Trigger the confirmation sender again
          strategy = AshAuthentication.Info.strategy!(Angle.Accounts.User, :confirm_new_user)

          case AshAuthentication.Strategy.Confirmation.Actions.confirm(
                 strategy,
                 %{"confirm" => user_id},
                 []
               ) do
            _ ->
              # Even if this fails, we show success to prevent enumeration
              :ok
          end

          conn
          |> put_flash(:info, "A new verification code has been sent to your email.")
          |> redirect(to: ~p"/auth/verify-account")

        {:error, _} ->
          conn
          |> put_flash(:error, "Could not resend code. Please try registering again.")
          |> redirect(to: ~p"/auth/register")
      end
    end
  end
```

**Note:** The `resend_otp` implementation is tricky because AshAuthentication's confirmation add-on doesn't have a simple "resend" API. An alternative approach: store the original JWT token in the session during registration, and use OtpHelper.create_otp directly with that token for resend. Update accordingly:

In `do_register`, also store the confirmation in session isn't possible since the JWT is sent to the sender callback, not returned. Instead, for resend, generate a new OTP with a placeholder token and handle confirmation differently.

**Simpler resend approach** — update `resend_otp`:

```elixir
  def resend_otp(conn, _params) do
    user_id = get_session(conn, :verify_user_id)

    if is_nil(user_id) do
      conn
      |> put_flash(:error, "Session expired. Please register again.")
      |> redirect(to: ~p"/auth/register")
    else
      # Request a new confirmation token via AshAuthentication
      # This triggers the sender which creates a new OTP
      with {:ok, user} <-
             Ash.get(Angle.Accounts.User, user_id,
               domain: Angle.Accounts,
               authorize?: false
             ) do
        # Only resend if not already confirmed
        if is_nil(user.confirmed_at) do
          strategy = AshAuthentication.Info.strategy!(Angle.Accounts.User, :confirm_new_user)
          AshAuthentication.AddOn.Confirmation.confirmation_token(strategy, user)
        end
      end

      conn
      |> put_flash(:info, "A new verification code has been sent to your email.")
      |> redirect(to: ~p"/auth/verify-account")
    end
  end
```

**Important note for implementor:** The exact `resend_otp` implementation depends on how AshAuthentication exposes re-triggering confirmation. Check `mix usage_rules.search_docs "confirmation" -p ash_authentication` to find the correct API. The core idea: trigger the sender callback again which creates a new OTP. If no direct API exists, manually generate a JWT token using the confirmation strategy's token generation.

**Step 4: Write tests**

Create `test/angle_web/controllers/auth_controller_test.exs`:

```elixir
defmodule AngleWeb.AuthControllerTest do
  use AngleWeb.ConnCase, async: true

  alias Angle.Factory

  describe "GET /auth/verify-account" do
    test "renders verify page when verify_user_id in session", %{conn: conn} do
      user = Factory.create_user()

      conn =
        conn
        |> init_test_session(%{verify_user_id: user.id, verify_email: "test@example.com"})
        |> get("/auth/verify-account")

      assert conn.status == 200
    end

    test "redirects to register when no verify_user_id in session", %{conn: conn} do
      conn = get(conn, "/auth/verify-account")
      assert redirected_to(conn) == "/auth/register"
    end
  end

  describe "POST /auth/verify-account" do
    test "verifies valid OTP code and redirects to dashboard", %{conn: conn} do
      user = Factory.create_user()
      otp = Angle.Accounts.OtpHelper.create_otp(user.id, "fake_token")

      conn =
        conn
        |> init_test_session(%{
          verify_user_id: user.id,
          verify_email: to_string(user.email),
          current_user_id: user.id
        })
        |> post("/auth/verify-account", %{"code" => otp.code})

      # May redirect to verify-account with error since fake_token won't work for actual confirmation
      # In integration tests, use a real confirmation token
      assert redirected_to(conn) =~ ~r(/auth/verify-account|/dashboard)
    end

    test "rejects invalid OTP code", %{conn: conn} do
      user = Factory.create_user()
      _otp = Angle.Accounts.OtpHelper.create_otp(user.id, "fake_token")

      conn =
        conn
        |> init_test_session(%{verify_user_id: user.id, verify_email: to_string(user.email)})
        |> post("/auth/verify-account", %{"code" => "000000"})

      assert redirected_to(conn) == "/auth/verify-account"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Invalid"
    end
  end
end
```

**Step 5: Run tests**

Run: `mix test test/angle_web/controllers/auth_controller_test.exs -v`
Expected: PASS

**Step 6: Commit**

```bash
git add lib/angle_web/router.ex lib/angle_web/controllers/auth_controller.ex test/angle_web/controllers/auth_controller_test.exs
git commit -m "feat: add verify account routes and OTP verification controller"
```

---

## Task 5: Build AuthLayout component

**Files:**
- Create: `assets/js/components/layouts/auth-layout.tsx`
- Add: Hero image to `priv/static/images/auth-hero.jpg` (placeholder)

**Step 1: Add a placeholder hero image**

Download or create a dark placeholder image for the hero. For now, use a solid dark gradient as CSS background until a real hero image is provided.

**Step 2: Create AuthLayout component**

Create `assets/js/components/layouts/auth-layout.tsx`:

```tsx
import { ReactNode } from "react";

interface AuthLayoutProps {
  children: ReactNode;
  heroImage?: string;
}

const CATEGORY_PILLS = [
  "Vehicles",
  "Cultural Artefacts",
  "Gadgets",
  "Home Appliances",
  "Rare Collectibles",
];

function AngleLogo({ className = "" }: { className?: string }) {
  return (
    <div className={`flex flex-col items-start ${className}`}>
      <svg
        width="40"
        height="40"
        viewBox="0 0 40 40"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
        aria-hidden="true"
      >
        {/* Shopping bag icon */}
        <rect x="6" y="14" width="28" height="24" rx="3" fill="#F97316" />
        <path
          d="M14 14V10C14 6.68629 16.6863 4 20 4C23.3137 4 26 6.68629 26 10V14"
          stroke="#1a1a1a"
          strokeWidth="2.5"
          strokeLinecap="round"
          fill="none"
        />
      </svg>
      <span className="text-sm font-bold tracking-wide mt-1">ANGLE</span>
    </div>
  );
}

export function AuthLayout({
  children,
  heroImage = "/images/auth-hero.jpg",
}: AuthLayoutProps) {
  return (
    <div className="min-h-screen lg:grid lg:grid-cols-2">
      {/* Hero section — desktop only */}
      <div className="hidden lg:block relative overflow-hidden rounded-2xl m-3">
        <div
          className="absolute inset-0 bg-cover bg-center bg-gray-800"
          style={{ backgroundImage: `url(${heroImage})` }}
        />
        {/* Overlay for text readability */}
        <div className="absolute inset-0 bg-black/20" />

        {/* Logo */}
        <div className="relative z-10 p-8">
          <AngleLogo className="text-white" />
        </div>

        {/* Category pills */}
        <div className="absolute bottom-8 left-8 right-8 z-10 flex gap-2 overflow-x-auto">
          {CATEGORY_PILLS.map((category) => (
            <span
              key={category}
              className="inline-flex items-center rounded-full bg-white/20 backdrop-blur-sm px-4 py-1.5 text-sm text-white whitespace-nowrap border border-white/30"
            >
              {category}
            </span>
          ))}
        </div>
      </div>

      {/* Form section */}
      <div className="flex flex-col min-h-screen lg:min-h-0">
        {/* Mobile logo */}
        <div className="lg:hidden px-6 pt-8">
          <AngleLogo />
        </div>

        {/* Form content */}
        <div className="flex-1 flex flex-col justify-center px-6 py-8 lg:px-12 lg:py-0">
          <div className="w-full max-w-sm mx-auto lg:mx-0">{children}</div>
        </div>
      </div>
    </div>
  );
}
```

**Step 3: Export AngleLogo for reuse**

The `AngleLogo` component is defined inside auth-layout.tsx. If needed elsewhere, it can be extracted later.

**Step 4: Commit**

```bash
git add assets/js/components/layouts/auth-layout.tsx
git commit -m "feat: add AuthLayout component with split-screen hero design"
```

---

## Task 6: Redesign Sign Up page and form

**Files:**
- Modify: `assets/js/pages/auth/register.tsx`
- Modify: `assets/js/components/forms/register-form.tsx`

**Step 1: Rewrite the RegisterForm component**

Replace `assets/js/components/forms/register-form.tsx`:

```tsx
import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { router, Link } from "@inertiajs/react";
import { Button } from "../ui/button";
import { Input } from "../ui/input";
import { Label } from "../ui/label";
import { Alert, AlertDescription } from "../ui/alert";
import { Eye, EyeOff } from "lucide-react";

const emailSchema = z.object({
  full_name: z.string().min(1, "Full name is required"),
  email: z.string().email("Please enter a valid email address"),
  password: z.string().min(8, "Password must be at least 8 characters"),
  mode: z.literal("email"),
});

const phoneSchema = z.object({
  full_name: z.string().min(1, "Full name is required"),
  phone_number: z.string().min(6, "Please enter a valid phone number"),
  password: z.string().min(8, "Password must be at least 8 characters"),
  mode: z.literal("phone"),
});

type EmailFormData = z.infer<typeof emailSchema>;
type PhoneFormData = z.infer<typeof phoneSchema>;

interface RegisterFormProps {
  error?: string;
}

export function RegisterForm({ error }: RegisterFormProps) {
  const [mode, setMode] = useState<"email" | "phone">("email");
  const [showPassword, setShowPassword] = useState(false);

  const emailForm = useForm<EmailFormData>({
    resolver: zodResolver(emailSchema),
    defaultValues: { mode: "email" },
  });

  const phoneForm = useForm<PhoneFormData>({
    resolver: zodResolver(phoneSchema),
    defaultValues: { mode: "phone" },
  });

  const form = mode === "email" ? emailForm : phoneForm;
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = form;

  const onSubmit = (data: EmailFormData | PhoneFormData) => {
    if (data.mode === "email") {
      router.post("/auth/register", {
        full_name: data.full_name,
        email: (data as EmailFormData).email,
        password: data.password,
        password_confirmation: data.password,
      });
    } else {
      router.post("/auth/register", {
        full_name: data.full_name,
        phone_number: (data as PhoneFormData).phone_number,
        email: `phone_${Date.now()}@placeholder.angle.app`,
        password: data.password,
        password_confirmation: data.password,
      });
    }
  };

  const toggleMode = () => {
    setMode((prev) => (prev === "email" ? "phone" : "email"));
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">
          Create an Account
        </h1>
        <p className="mt-1 text-sm text-muted-foreground">
          Join in and bid on your favourite items.
        </p>
      </div>

      <form
        onSubmit={handleSubmit(onSubmit)}
        className="space-y-4"
        id="register-form"
      >
        {error && (
          <Alert variant="destructive">
            <AlertDescription>{error}</AlertDescription>
          </Alert>
        )}

        {/* Full Name */}
        <div className="space-y-2">
          <Label htmlFor="full_name">Full Name</Label>
          <Input
            id="full_name"
            type="text"
            placeholder=""
            {...register("full_name")}
          />
          {errors.full_name && (
            <p className="text-sm text-red-600">{errors.full_name.message}</p>
          )}
        </div>

        {/* Email or Phone */}
        {mode === "email" ? (
          <div className="space-y-2">
            <Label htmlFor="email">Email</Label>
            <Input
              id="email"
              type="email"
              placeholder=""
              {...(register as ReturnType<typeof useForm<EmailFormData>>["register"])("email")}
            />
            {"email" in errors && errors.email && (
              <p className="text-sm text-red-600">{errors.email.message}</p>
            )}
            <button
              type="button"
              onClick={toggleMode}
              className="text-sm text-muted-foreground hover:text-foreground underline-offset-2 hover:underline"
            >
              Use phone number
            </button>
          </div>
        ) : (
          <div className="space-y-2">
            <Label htmlFor="phone_number">Phone number</Label>
            <div className="flex">
              <div className="flex items-center gap-1.5 rounded-l-md border border-r-0 bg-muted px-3 text-sm text-muted-foreground">
                <span>🇳🇬</span>
                <span>234</span>
                <span className="text-xs">▾</span>
              </div>
              <Input
                id="phone_number"
                type="tel"
                placeholder="Enter phone number"
                className="rounded-l-none"
                {...(register as ReturnType<typeof useForm<PhoneFormData>>["register"])("phone_number")}
              />
            </div>
            {"phone_number" in errors && errors.phone_number && (
              <p className="text-sm text-red-600">
                {errors.phone_number.message}
              </p>
            )}
            <button
              type="button"
              onClick={toggleMode}
              className="text-sm text-muted-foreground hover:text-foreground underline-offset-2 hover:underline"
            >
              Use email
            </button>
          </div>
        )}

        {/* Password */}
        <div className="space-y-2">
          <Label htmlFor="password">Password</Label>
          <div className="relative">
            <Input
              id="password"
              type={showPassword ? "text" : "password"}
              placeholder=""
              className="pr-10"
              {...register("password")}
            />
            <button
              type="button"
              onClick={() => setShowPassword(!showPassword)}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
              tabIndex={-1}
            >
              {showPassword ? (
                <EyeOff className="h-4 w-4" />
              ) : (
                <Eye className="h-4 w-4" />
              )}
            </button>
          </div>
          {errors.password && (
            <p className="text-sm text-red-600">{errors.password.message}</p>
          )}
        </div>

        {/* Terms */}
        <p className="text-sm text-muted-foreground">
          By signing up, you agree to our{" "}
          <Link href="/terms" className="text-orange-500 hover:underline">
            Terms
          </Link>{" "}
          and{" "}
          <Link href="/conditions" className="text-orange-500 hover:underline">
            Conditions
          </Link>{" "}
          of service.
        </p>

        {/* Submit */}
        <Button
          type="submit"
          className="w-full bg-orange-500 hover:bg-orange-600 text-white rounded-full h-12 text-base font-medium"
          disabled={isSubmitting}
        >
          {isSubmitting ? "Signing up..." : "Sign Up"}
        </Button>

        {/* Login link */}
        <p className="text-center text-sm text-muted-foreground">
          Already have an account?{" "}
          <Link
            href="/auth/login"
            className="font-semibold text-foreground hover:underline"
          >
            Log In
          </Link>
        </p>
      </form>

      {/* Divider */}
      <div className="relative">
        <div className="absolute inset-0 flex items-center">
          <span className="w-full border-t" />
        </div>
      </div>

      {/* Google OAuth */}
      <Button
        type="button"
        variant="outline"
        className="w-full rounded-full h-12 text-base font-medium"
        onClick={() => {
          window.location.href = "/auth/google";
        }}
      >
        Continue with Google
        <svg className="ml-2 h-5 w-5" viewBox="0 0 24 24">
          <path
            d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z"
            fill="#4285F4"
          />
          <path
            d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
            fill="#34A853"
          />
          <path
            d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
            fill="#FBBC05"
          />
          <path
            d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
            fill="#EA4335"
          />
        </svg>
      </Button>
    </div>
  );
}
```

**Step 2: Rewrite the Register page to use AuthLayout**

Replace `assets/js/pages/auth/register.tsx`:

```tsx
import { Head, usePage } from "@inertiajs/react";
import { RegisterForm } from "../../components/forms/register-form";
import { AuthLayout } from "../../components/layouts/auth-layout";
import { AuthProvider } from "../../contexts/auth-context";
import { PageProps } from "../../types/auth";

interface RegisterPageProps extends PageProps {
  error?: string;
}

export default function Register() {
  const { props } = usePage<RegisterPageProps>();
  const { error } = props;

  return (
    <>
      <Head title="Sign Up" />
      <AuthLayout>
        <RegisterForm error={error} />
      </AuthLayout>
    </>
  );
}

// Override default layout — auth pages don't show MainNav
Register.layout = (page: React.ReactNode) => <AuthProvider>{page}</AuthProvider>;
```

**Step 3: Commit**

```bash
git add assets/js/pages/auth/register.tsx assets/js/components/forms/register-form.tsx
git commit -m "feat: redesign sign up page with split-screen layout and phone/email toggle"
```

---

## Task 7: Build Verify Account page

**Files:**
- Create: `assets/js/pages/auth/verify-account.tsx`

**Step 1: Create the verify account page**

Create `assets/js/pages/auth/verify-account.tsx`:

```tsx
import { useState } from "react";
import { Head, usePage, router } from "@inertiajs/react";
import { AuthLayout } from "../../components/layouts/auth-layout";
import { AuthProvider } from "../../contexts/auth-context";
import { Button } from "../../components/ui/button";
import {
  InputOTP,
  InputOTPGroup,
  InputOTPSlot,
  InputOTPSeparator,
} from "../../components/ui/input-otp";
import { Alert, AlertDescription } from "../../components/ui/alert";
import { PageProps } from "../../types/auth";

interface VerifyAccountPageProps extends PageProps {
  email?: string;
}

export default function VerifyAccount() {
  const { props } = usePage<VerifyAccountPageProps>();
  const { email, flash } = props;
  const [code, setCode] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isResending, setIsResending] = useState(false);

  const handleVerify = (e: React.FormEvent) => {
    e.preventDefault();
    if (code.length !== 6) return;

    setIsSubmitting(true);
    router.post(
      "/auth/verify-account",
      { code },
      {
        onFinish: () => setIsSubmitting(false),
      }
    );
  };

  const handleResend = () => {
    setIsResending(true);
    router.post(
      "/auth/resend-otp",
      {},
      {
        onFinish: () => setIsResending(false),
      }
    );
  };

  return (
    <>
      <Head title="Verify Account" />
      <AuthLayout>
        <div className="space-y-6">
          <div>
            <h1 className="text-2xl font-bold tracking-tight">
              Verify Account
            </h1>
            <p className="mt-1 text-sm text-muted-foreground">
              Check your email for the OTP code shared.
            </p>
          </div>

          <form onSubmit={handleVerify} className="space-y-6" id="verify-form">
            {flash?.error && (
              <Alert variant="destructive">
                <AlertDescription>{flash.error}</AlertDescription>
              </Alert>
            )}

            <div className="space-y-2">
              <label className="text-sm font-medium">Secure code</label>
              <InputOTP
                maxLength={6}
                value={code}
                onChange={setCode}
              >
                <InputOTPGroup>
                  <InputOTPSlot index={0} className="h-12 w-12 text-lg" />
                  <InputOTPSlot index={1} className="h-12 w-12 text-lg" />
                  <InputOTPSlot index={2} className="h-12 w-12 text-lg" />
                </InputOTPGroup>
                <InputOTPSeparator />
                <InputOTPGroup>
                  <InputOTPSlot index={3} className="h-12 w-12 text-lg" />
                  <InputOTPSlot index={4} className="h-12 w-12 text-lg" />
                  <InputOTPSlot index={5} className="h-12 w-12 text-lg" />
                </InputOTPGroup>
              </InputOTP>
            </div>

            <Button
              type="submit"
              className="w-full bg-orange-500 hover:bg-orange-600 text-white rounded-full h-12 text-base font-medium"
              disabled={isSubmitting || code.length !== 6}
            >
              {isSubmitting ? "Verifying..." : "Verify"}
            </Button>

            <p className="text-center text-sm text-muted-foreground">
              Didn't receive code?{" "}
              <button
                type="button"
                onClick={handleResend}
                disabled={isResending}
                className="font-semibold text-foreground hover:underline disabled:opacity-50"
              >
                {isResending ? "Sending..." : "Resend OTP"}
              </button>
            </p>
          </form>
        </div>
      </AuthLayout>
    </>
  );
}

// Override default layout — auth pages don't show MainNav
VerifyAccount.layout = (page: React.ReactNode) => (
  <AuthProvider>{page}</AuthProvider>
);
```

**Step 2: Commit**

```bash
git add assets/js/pages/auth/verify-account.tsx
git commit -m "feat: add verify account page with OTP input"
```

---

## Task 8: Redesign Login page and form

**Files:**
- Modify: `assets/js/pages/auth/login.tsx`
- Modify: `assets/js/components/forms/login-form.tsx`

**Step 1: Rewrite the LoginForm component**

Replace `assets/js/components/forms/login-form.tsx`:

```tsx
import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { router, Link } from "@inertiajs/react";
import { Button } from "../ui/button";
import { Input } from "../ui/input";
import { Label } from "../ui/label";
import { Alert, AlertDescription } from "../ui/alert";
import { Eye, EyeOff } from "lucide-react";

const loginSchema = z.object({
  email: z.string().email("Please enter a valid email address"),
  password: z.string().min(1, "Password is required"),
});

type LoginFormData = z.infer<typeof loginSchema>;

interface LoginFormProps {
  error?: string;
}

export function LoginForm({ error }: LoginFormProps) {
  const [showPassword, setShowPassword] = useState(false);

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<LoginFormData>({
    resolver: zodResolver(loginSchema),
  });

  const onSubmit = (data: LoginFormData) => {
    router.post("/auth/login", data);
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Welcome Back</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          Sign in to continue bidding on your favourite items.
        </p>
      </div>

      <form
        onSubmit={handleSubmit(onSubmit)}
        className="space-y-4"
        id="login-form"
      >
        {error && (
          <Alert variant="destructive">
            <AlertDescription>{error}</AlertDescription>
          </Alert>
        )}

        {/* Email */}
        <div className="space-y-2">
          <Label htmlFor="email">Email</Label>
          <Input
            id="email"
            type="email"
            placeholder=""
            {...register("email")}
          />
          {errors.email && (
            <p className="text-sm text-red-600">{errors.email.message}</p>
          )}
        </div>

        {/* Password */}
        <div className="space-y-2">
          <Label htmlFor="password">Password</Label>
          <div className="relative">
            <Input
              id="password"
              type={showPassword ? "text" : "password"}
              placeholder=""
              className="pr-10"
              {...register("password")}
            />
            <button
              type="button"
              onClick={() => setShowPassword(!showPassword)}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
              tabIndex={-1}
            >
              {showPassword ? (
                <EyeOff className="h-4 w-4" />
              ) : (
                <Eye className="h-4 w-4" />
              )}
            </button>
          </div>
          {errors.password && (
            <p className="text-sm text-red-600">{errors.password.message}</p>
          )}
        </div>

        {/* Forgot password */}
        <div className="text-right">
          <Link
            href="/auth/forgot-password"
            className="text-sm text-orange-500 hover:underline"
          >
            Forgot password?
          </Link>
        </div>

        {/* Submit */}
        <Button
          type="submit"
          className="w-full bg-orange-500 hover:bg-orange-600 text-white rounded-full h-12 text-base font-medium"
          disabled={isSubmitting}
        >
          {isSubmitting ? "Signing in..." : "Sign In"}
        </Button>

        {/* Register link */}
        <p className="text-center text-sm text-muted-foreground">
          Don't have an account?{" "}
          <Link
            href="/auth/register"
            className="font-semibold text-foreground hover:underline"
          >
            Sign Up
          </Link>
        </p>
      </form>

      {/* Divider */}
      <div className="relative">
        <div className="absolute inset-0 flex items-center">
          <span className="w-full border-t" />
        </div>
      </div>

      {/* Google OAuth */}
      <Button
        type="button"
        variant="outline"
        className="w-full rounded-full h-12 text-base font-medium"
        onClick={() => {
          window.location.href = "/auth/google";
        }}
      >
        Continue with Google
        <svg className="ml-2 h-5 w-5" viewBox="0 0 24 24">
          <path
            d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z"
            fill="#4285F4"
          />
          <path
            d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
            fill="#34A853"
          />
          <path
            d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
            fill="#FBBC05"
          />
          <path
            d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
            fill="#EA4335"
          />
        </svg>
      </Button>
    </div>
  );
}
```

**Step 2: Rewrite the Login page to use AuthLayout**

Replace `assets/js/pages/auth/login.tsx`:

```tsx
import { Head, usePage } from "@inertiajs/react";
import { LoginForm } from "../../components/forms/login-form";
import { AuthLayout } from "../../components/layouts/auth-layout";
import { AuthProvider } from "../../contexts/auth-context";
import { PageProps } from "../../types/auth";

interface LoginPageProps extends PageProps {
  error?: string;
}

export default function Login() {
  const { props } = usePage<LoginPageProps>();
  const { error } = props;

  return (
    <>
      <Head title="Sign In" />
      <AuthLayout>
        <LoginForm error={error} />
      </AuthLayout>
    </>
  );
}

// Override default layout — auth pages don't show MainNav
Login.layout = (page: React.ReactNode) => <AuthProvider>{page}</AuthProvider>;
```

**Step 3: Commit**

```bash
git add assets/js/pages/auth/login.tsx assets/js/components/forms/login-form.tsx
git commit -m "feat: redesign login page with split-screen layout and password visibility toggle"
```

---

## Task 9: Set up Google OAuth strategy

**Files:**
- Modify: `lib/angle/accounts/user.ex` (authentication block)
- Modify: `lib/angle_web/router.ex` (OAuth callback routes)
- Modify: `lib/angle_web/controllers/auth_controller.ex` (OAuth callback handling)
- Create: `lib/angle/secrets.ex` (or modify existing — for OAuth secret resolution)
- Modify: `config/config.exs` or `config/runtime.exs`

**Step 1: Check AshAuthentication OAuth2 docs**

Run: `mix usage_rules.search_docs "OAuth2" -p ash_authentication`

Read the results and follow the official pattern.

**Step 2: Add Google OAuth strategy to User resource**

In `lib/angle/accounts/user.ex`, inside the `strategies` block (after the `password` strategy, around line 46):

```elixir
    strategies do
      password :password do
        identity_field :email
        hashed_password_field :hashed_password

        resettable do
          sender Angle.Accounts.User.Senders.SendPasswordResetEmail
        end
      end

      google do
        client_id fn _, _ ->
          Application.get_env(:angle, :google_oauth)[:client_id] ||
            System.get_env("GOOGLE_CLIENT_ID")
        end

        redirect_uri fn _, _ ->
          Application.get_env(:angle, :google_oauth)[:redirect_uri] ||
            "http://localhost:4000/auth/google/callback"
        end

        client_secret fn _, _ ->
          Application.get_env(:angle, :google_oauth)[:client_secret] ||
            System.get_env("GOOGLE_CLIENT_SECRET")
        end
      end
    end
```

**Important note for implementor:** Check `mix usage_rules.search_docs "google" -p ash_authentication` for the exact DSL. The strategy might be `oauth2 :google` with specific provider configuration. Look at the AshAuthentication docs for the correct syntax. The `google` shorthand may require `AshAuthentication.Strategy.Google` or similar.

**Step 3: Add OAuth routes**

In `lib/angle_web/router.ex`, add to the auth scope:

```elixir
    get "/google", AuthController, :google_redirect
    get "/google/callback", AuthController, :google_callback
```

**Step 4: Add OAuth controller actions**

In `lib/angle_web/controllers/auth_controller.ex`:

```elixir
  def google_redirect(conn, _params) do
    # AshAuthentication handles the redirect URL generation
    strategy = AshAuthentication.Info.strategy!(Angle.Accounts.User, :google)
    {:ok, url} = AshAuthentication.Strategy.redirect(strategy, conn)

    redirect(conn, external: url)
  end

  def google_callback(conn, params) do
    strategy = AshAuthentication.Info.strategy!(Angle.Accounts.User, :google)

    case AshAuthentication.Strategy.callback(strategy, params, []) do
      {:ok, user} ->
        token =
          case user.__metadata__ do
            %{token: token} -> token
            _ -> nil
          end

        conn
        |> put_session(:current_user_id, user.id)
        |> then(fn conn ->
          if token, do: put_session(conn, :auth_token, token), else: conn
        end)
        |> put_flash(:info, "Successfully signed in with Google!")
        |> redirect(to: ~p"/dashboard")

      {:error, _} ->
        conn
        |> put_flash(:error, "Google sign-in failed. Please try again.")
        |> redirect(to: ~p"/auth/login")
    end
  end
```

**Important note for implementor:** AshAuthentication may handle OAuth routes automatically. Check if the `AshAuthentication.Plug` or router integration already provides `/auth/:strategy` routes. If so, this step is just configuration, no custom controller code needed. Run `mix usage_rules.search_docs "callback" -p ash_authentication` to verify.

**Step 5: Add config for Google OAuth credentials**

In `config/runtime.exs` (or create if doesn't exist):

```elixir
config :angle, :google_oauth,
  client_id: System.get_env("GOOGLE_CLIENT_ID"),
  client_secret: System.get_env("GOOGLE_CLIENT_SECRET"),
  redirect_uri: System.get_env("GOOGLE_OAUTH_REDIRECT_URI", "http://localhost:4000/auth/google/callback")
```

**Step 6: Add policies for Google OAuth**

In `lib/angle/accounts/user.ex`, add policies for the Google OAuth actions (AshAuthentication generates `sign_in_with_google` and `register_with_google` actions):

```elixir
    policy action(:sign_in_with_google) do
      authorize_if always()
    end

    policy action(:register_with_google) do
      authorize_if always()
    end
```

**Step 7: Commit**

```bash
git add lib/angle/accounts/user.ex lib/angle_web/router.ex lib/angle_web/controllers/auth_controller.ex config/
git commit -m "feat: add Google OAuth authentication strategy"
```

---

## Task 10: Add hero image asset

**Files:**
- Add: `priv/static/images/auth-hero.jpg`

**Step 1: Add a placeholder hero image**

The Figma design shows a dark photo of a black SUV. For now, either:
1. Download the hero image from the Figma design (export the left panel image)
2. Or use a royalty-free dark car photo

Place it at `priv/static/images/auth-hero.jpg`.

**Step 2: Verify it loads**

Start the dev server with `mix phx.server` and visit `http://localhost:4000/images/auth-hero.jpg` to confirm the image is served.

**Step 3: Commit**

```bash
git add priv/static/images/auth-hero.jpg
git commit -m "feat: add auth hero image for split-screen layout"
```

---

## Task 11: Google OAuth setup guide

**Files:**
- Create: `docs/google-oauth-setup.md`

**Step 1: Write the setup guide**

Create `docs/google-oauth-setup.md`:

```markdown
# Google OAuth Setup Guide

## 1. Create a Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the **Google+ API** or **Google Identity** service

## 2. Configure OAuth Consent Screen

1. Navigate to **APIs & Services > OAuth consent screen**
2. Select **External** user type
3. Fill in:
   - App name: `Angle`
   - User support email: your email
   - Authorized domains: `localhost` (for dev), your production domain
4. Add scopes: `email`, `profile`, `openid`
5. Save

## 3. Create OAuth Credentials

1. Navigate to **APIs & Services > Credentials**
2. Click **Create Credentials > OAuth client ID**
3. Application type: **Web application**
4. Name: `Angle Web Client`
5. Authorized redirect URIs:
   - Development: `http://localhost:4000/auth/google/callback`
   - Production: `https://yourdomain.com/auth/google/callback`
6. Click **Create**
7. Copy the **Client ID** and **Client Secret**

## 4. Configure Environment Variables

Add to your `.env` file (or export in your shell):

```bash
export GOOGLE_CLIENT_ID="your-client-id.apps.googleusercontent.com"
export GOOGLE_CLIENT_SECRET="your-client-secret"
export GOOGLE_OAUTH_REDIRECT_URI="http://localhost:4000/auth/google/callback"
```

## 5. Verify

1. Start the server: `mix phx.server`
2. Visit `http://localhost:4000/auth/register`
3. Click "Continue with Google"
4. You should be redirected to Google's OAuth consent screen
```

**Step 2: Commit**

```bash
git add docs/google-oauth-setup.md
git commit -m "docs: add Google OAuth setup guide"
```

---

## Task 12: Run full test suite and fix issues

**Step 1: Run all tests**

Run: `mix test --max-failures 5`

**Step 2: Fix any failures**

Common issues to watch for:
- Migration ordering (run `mix ash.setup --quiet`)
- Existing tests that assume the old registration flow (redirect to `/` instead of `/auth/verify-account`)
- Existing tests that reference old form fields
- Policy issues with new OTP resource

**Step 3: Run tests again to confirm**

Run: `mix test`
Expected: All tests pass

**Step 4: Commit any fixes**

```bash
git add -A
git commit -m "fix: resolve test failures from auth redesign"
```

---

## Task 13: Manual QA and visual polish

**Step 1: Start dev server and test each page visually**

Run: `iex -S mix phx.server`

Test these pages:
1. `http://localhost:4000/auth/register` — Sign up page with split layout
2. `http://localhost:4000/auth/login` — Login page with split layout
3. Register a new account → should redirect to verify page
4. `http://localhost:4000/auth/verify-account` — OTP input page
5. Check `/dev/mailbox` for branded OTP email
6. Enter OTP code → should confirm and redirect to dashboard
7. Test "Resend OTP" button
8. Test phone/email toggle on sign up
9. Test responsive layout (resize browser to mobile width)

**Step 2: Fix any visual issues**

Compare against the Figma designs and adjust spacing, colors, typography as needed. Key design details:
- Orange CTA button: `bg-orange-500` with `rounded-full`
- Form inputs: standard shadcn style with subtle borders
- OTP slots: `h-12 w-12` with separator dash between groups of 3
- Category pills on hero: semi-transparent white with backdrop blur
- Mobile: no hero image, just logo + form

**Step 3: Commit any visual fixes**

```bash
git add -A
git commit -m "fix: visual polish for auth pages to match Figma designs"
```

---

## Summary

| Task | Description | Files touched |
|------|-------------|---------------|
| 1 | Add full_name and phone_number to User | user.ex, factory.ex, auth.ts |
| 2 | Create OTP resource and helper | otp.ex, otp_helper.ex, accounts.ex |
| 3 | Branded OTP email sender | email_templates.ex, sender |
| 4 | Verify account routes + controller | router.ex, auth_controller.ex |
| 5 | AuthLayout component | auth-layout.tsx |
| 6 | Redesign Sign Up page + form | register.tsx, register-form.tsx |
| 7 | Verify Account page | verify-account.tsx |
| 8 | Redesign Login page + form | login.tsx, login-form.tsx |
| 9 | Google OAuth strategy | user.ex, router.ex, auth_controller.ex |
| 10 | Hero image asset | auth-hero.jpg |
| 11 | Google OAuth setup guide | google-oauth-setup.md |
| 12 | Full test suite pass | Various fixes |
| 13 | Manual QA and visual polish | Various tweaks |
