# Google OAuth Completion Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Complete Google OAuth with account linking, environment documentation, error handling, and testing.

**Architecture:** Extend existing AshAuthentication Google OAuth setup with account linking logic. When user signs in with Google, check if email exists - if yes, link OAuth to existing account; if no, create new user. Handle errors gracefully with flash messages.

**Tech Stack:** Elixir, Phoenix, Ash Framework, AshAuthentication, Inertia.js

---

## Task 1: Environment Documentation

**Files:**
- Modify: `.env.example`

**Step 1: Update .env.example with Google OAuth variables**

Add these lines to `.env.example`:

```bash
# Google OAuth (required for social login)
# Get credentials from: https://console.cloud.google.com/apis/credentials
GOOGLE_CLIENT_ID=your_google_client_id_here
GOOGLE_CLIENT_SECRET=your_google_client_secret_here
```

**Step 2: Verify changes**

Run: `cat .env.example | grep GOOGLE`

Expected: Should show the two new GOOGLE_* variables

**Step 3: Commit**

```bash
git add .env.example
git commit -m "docs: add Google OAuth environment variables to .env.example

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 2: Setup Documentation

**Files:**
- Create: `docs/setup/google-oauth.md`

**Step 1: Create docs/setup directory if needed**

Run: `mkdir -p docs/setup`

**Step 2: Write Google OAuth setup guide**

Create `docs/setup/google-oauth.md` with this content:

```markdown
# Google OAuth Setup Guide

This guide explains how to set up Google OAuth authentication for local development and production.

## Prerequisites

- Google Cloud Console account
- Phoenix server running on port 4111 (local) or production domain

## Getting Google OAuth Credentials

1. **Go to Google Cloud Console**
   - Visit: https://console.cloud.google.com/apis/credentials
   - Select your project or create a new one

2. **Create OAuth 2.0 Client ID**
   - Click "Create Credentials" → "OAuth 2.0 Client ID"
   - Application type: "Web application"
   - Name: "Angle Auction Platform" (or your preferred name)

3. **Configure Authorized Redirect URIs**

   **For local development:**
   ```
   http://localhost:4111/auth/user/google/callback
   ```

   **For production:**
   ```
   https://yourdomain.com/auth/user/google/callback
   ```

   Click "Create" to generate credentials.

4. **Copy Credentials**
   - Copy the **Client ID** and **Client Secret**
   - Keep these secure - never commit to git

## Local Development Setup

1. **Copy environment template**
   ```bash
   cp .env.example .env
   ```

2. **Set environment variables**

   Edit `.env` and add your credentials:
   ```bash
   GOOGLE_CLIENT_ID=your_actual_client_id_here
   GOOGLE_CLIENT_SECRET=your_actual_client_secret_here
   ```

3. **Verify configuration**

   The redirect URI is configured in `lib/angle/secrets.ex` and defaults to:
   ```
   http://localhost:4111/auth/user/google/callback
   ```

   This matches the URI you configured in Google Console.

4. **Start Phoenix server**
   ```bash
   mix phx.server
   ```

   Server should start on port 4111.

5. **Test OAuth flow**
   - Navigate to http://localhost:4111/auth/login
   - Click "Continue with Google"
   - You should be redirected to Google's consent screen
   - After authorizing, you should be redirected back to dashboard

## Production Deployment

1. **Update redirect URI in Google Console**
   - Add your production domain to authorized redirect URIs
   - Example: `https://yourdomain.com/auth/user/google/callback`

2. **Set environment variables**

   In your production environment (Heroku, Fly.io, etc.):
   ```bash
   GOOGLE_CLIENT_ID=your_production_client_id
   GOOGLE_CLIENT_SECRET=your_production_client_secret
   ```

3. **Update redirect URI configuration (optional)**

   If your production redirect URI differs from the default, set:
   ```bash
   GOOGLE_OAUTH_REDIRECT_URI=https://yourdomain.com/auth/user/google/callback
   ```

4. **Verify SSL certificate**
   - Google requires HTTPS for production OAuth
   - Ensure your production domain has a valid SSL certificate

## How It Works

### New User Registration
1. User clicks "Continue with Google"
2. Google OAuth consent screen appears
3. User authorizes application
4. Google redirects back with OAuth code
5. Backend exchanges code for access token
6. User info fetched from Google (email, name)
7. New user created with "bidder" role
8. User redirected to dashboard

### Account Linking
1. User with existing email/password account clicks "Continue with Google"
2. OAuth flow completes (steps 2-6 above)
3. System detects email already exists
4. Google OAuth linked to existing account
5. Existing account data preserved
6. User redirected to dashboard

### Error Handling
If OAuth fails (user denies, network error, etc.), user sees friendly error message and is redirected to login page.

## Troubleshooting

**"Redirect URI mismatch" error:**
- Verify the URI in Google Console exactly matches `http://localhost:4111/auth/user/google/callback`
- Check for trailing slashes or protocol differences (http vs https)

**"Invalid client" error:**
- Verify GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET are set correctly in `.env`
- Check for extra spaces or quotes in environment variables

**OAuth works locally but fails in production:**
- Verify production redirect URI is added to Google Console
- Verify SSL certificate is valid
- Check production environment variables are set

## Security Notes

- Never commit `.env` file to git
- Keep Client Secret secure
- Use separate OAuth credentials for development and production
- Rotate credentials if compromised
```

**Step 3: Verify file created**

Run: `cat docs/setup/google-oauth.md | head -20`

Expected: Should show the first 20 lines of the guide

**Step 4: Commit**

```bash
git add docs/setup/google-oauth.md
git commit -m "docs: add Google OAuth setup guide

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 3: Account Linking Tests (Write Failing Tests)

**Files:**
- Modify or Create: `test/angle/accounts/user_test.exs`

Before implementing account linking, we need to understand the current User resource and test setup.

**Step 1: Check if test file exists**

Run: `ls -la test/angle/accounts/user_test.exs`

Expected: File may or may not exist. If it doesn't, we'll create it.

**Step 2: Read current User resource to understand structure**

Run: `grep -A 5 "register_with_google" lib/angle/accounts/user.ex`

Expected: Shows the current `register_with_google` action definition

**Step 3: Read test factory to understand how to create users**

Run: `grep -A 10 "def create_user" test/support/factory.ex`

Expected: Shows the factory function for creating test users

**Step 4: Write failing tests for OAuth registration and linking**

Create or modify `test/angle/accounts/user_test.exs`:

```elixir
defmodule Angle.Accounts.UserTest do
  use Angle.DataCase, async: true

  alias Angle.Accounts
  alias Angle.Accounts.User

  describe "register_with_google/1" do
    test "creates new user with valid Google OAuth data" do
      user_info = %{
        "email" => "newuser@example.com",
        "name" => "New User",
        "picture" => "https://example.com/photo.jpg"
      }

      oauth_tokens = %{
        "access_token" => "mock_access_token",
        "refresh_token" => "mock_refresh_token"
      }

      # This should create a new user
      assert {:ok, user} =
               Accounts.User
               |> Ash.Changeset.for_create(:register_with_google, %{
                 user_info: user_info,
                 oauth_tokens: oauth_tokens
               })
               |> Ash.create()

      assert user.email == "newuser@example.com"
      assert user.name == "New User"

      # Verify bidder role was assigned
      user_with_roles = Ash.load!(user, :roles)
      role_names = Enum.map(user_with_roles.roles, & &1.name)
      assert "bidder" in role_names
    end

    test "links Google OAuth to existing user when email matches" do
      # Create existing user with email/password
      existing_user = create_user(%{
        email: "existing@example.com",
        name: "Existing User",
        hashed_password: Bcrypt.hash_pwd_salt("password123")
      })

      user_info = %{
        "email" => "existing@example.com",
        "name" => "Existing User via Google",
        "picture" => "https://example.com/photo.jpg"
      }

      oauth_tokens = %{
        "access_token" => "mock_access_token",
        "refresh_token" => "mock_refresh_token"
      }

      # This should link OAuth to existing account, not create new user
      assert {:ok, updated_user} =
               Accounts.User
               |> Ash.Changeset.for_create(:register_with_google, %{
                 user_info: user_info,
                 oauth_tokens: oauth_tokens
               })
               |> Ash.create()

      # Should return the existing user, not create a new one
      assert updated_user.id == existing_user.id
      assert updated_user.email == existing_user.email

      # Original name should be preserved (not overwritten by Google)
      assert updated_user.name == "Existing User"

      # OAuth tokens should be stored
      # Note: These might be stored in a separate authentication_tokens table
      # depending on AshAuthentication's implementation
    end

    test "returns error when email is missing from user_info" do
      user_info = %{
        "name" => "User Without Email",
        "picture" => "https://example.com/photo.jpg"
      }

      oauth_tokens = %{
        "access_token" => "mock_access_token",
        "refresh_token" => "mock_refresh_token"
      }

      assert {:error, %Ash.Error.Invalid{} = error} =
               Accounts.User
               |> Ash.Changeset.for_create(:register_with_google, %{
                 user_info: user_info,
                 oauth_tokens: oauth_tokens
               })
               |> Ash.create()

      # Should have validation error about missing email
      assert error.errors |> Enum.any?(fn err ->
        err.field == :email && err.message =~ "required"
      end)
    end
  end
end
```

**Step 5: Run tests to verify they fail**

Run: `mix test test/angle/accounts/user_test.exs`

Expected: Tests should FAIL because account linking logic doesn't exist yet

The output should show failures like:
- "creates new user" might pass (already implemented)
- "links Google OAuth to existing user" should FAIL (not implemented)
- "returns error when email is missing" should FAIL (validation not implemented)

**Step 6: Commit failing tests**

```bash
git add test/angle/accounts/user_test.exs
git commit -m "test: add failing tests for Google OAuth account linking

Tests verify:
- New user registration via Google OAuth
- Account linking when email exists
- Error handling for missing email

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 4: Account Linking Implementation

**Files:**
- Modify: `lib/angle/accounts/user.ex`

**Step 1: Read current register_with_google action**

Run: `grep -A 30 "register_with_google" lib/angle/accounts/user.ex`

Expected: Shows the current action definition with user_info and oauth_tokens arguments

**Step 2: Understand AshAuthentication's default behavior**

Before modifying, we need to check if AshAuthentication already handles account linking or if we need custom logic.

Run: `mix usage_rules.search_docs "oauth account linking" -p ash_authentication`

Expected: Documentation about how AshAuthentication handles duplicate accounts

**Step 3: Implement account linking logic**

We need to add a `change` or `prepare` to the `register_with_google` action that:
1. Extracts email from user_info
2. Checks if user with that email exists
3. If exists: update existing user with OAuth tokens (link account)
4. If not: create new user (default behavior)

First, create a custom change module:

Create `lib/angle/accounts/user/changes/link_or_create_oauth_account.ex`:

```elixir
defmodule Angle.Accounts.User.Changes.LinkOrCreateOAuthAccount do
  @moduledoc """
  Custom change that handles account linking for OAuth registration.

  When a user signs in with Google:
  - If email exists: link OAuth to existing account
  - If email doesn't exist: create new user (default behavior)
  """
  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    # Extract email from user_info argument
    user_info = Ash.Changeset.get_argument(changeset, :user_info)
    email = get_in(user_info, ["email"])

    if email do
      # Check if user with this email already exists
      case Angle.Accounts.User
           |> Ash.Query.filter(email == ^email)
           |> Ash.read_one() do
        {:ok, nil} ->
          # No existing user - proceed with creation (default behavior)
          # Extract email from user_info and set it on changeset
          changeset
          |> Ash.Changeset.change_attribute(:email, email)
          |> Ash.Changeset.change_attribute(:name, get_in(user_info, ["name"]))

        {:ok, existing_user} ->
          # User exists - convert this to an update instead of create
          # We'll update the existing user with OAuth tokens
          changeset
          |> Ash.Changeset.set_context(%{existing_user_id: existing_user.id})
          |> Ash.Changeset.force_change_attribute(:id, existing_user.id)
          # Don't overwrite existing name - preserve user's data
          # Only update OAuth-specific fields

        {:error, error} ->
          # Query failed - add error to changeset
          Ash.Changeset.add_error(changeset, error)
      end
    else
      # No email in user_info - add validation error
      Ash.Changeset.add_error(
        changeset,
        field: :email,
        message: "email is required from OAuth provider"
      )
    end
  end
end
```

**Step 4: Update User resource to use the new change**

Modify `lib/angle/accounts/user.ex` to add the change to `register_with_google` action:

Find the `register_with_google` action and add the change:

```elixir
# In lib/angle/accounts/user.ex
# Find this action and add the change:

create :register_with_google do
  argument :user_info, :map, allow_nil?: false
  argument :oauth_tokens, :map, allow_nil?: false

  # Add this line:
  change Angle.Accounts.User.Changes.LinkOrCreateOAuthAccount

  # ... rest of existing action configuration
end
```

**Step 5: Run tests to verify they pass**

Run: `mix test test/angle/accounts/user_test.exs`

Expected: All tests should now PASS

Output should show:
```
...

Finished in 0.X seconds
3 tests, 0 failures
```

**Step 6: If tests fail, debug**

If tests still fail:

Run: `mix test test/angle/accounts/user_test.exs --trace`

Expected: Detailed output showing where the failure occurs

Fix issues based on test output, then run tests again until they pass.

**Step 7: Commit implementation**

```bash
git add lib/angle/accounts/user.ex lib/angle/accounts/user/changes/
git commit -m "feat: implement Google OAuth account linking

- Add LinkOrCreateOAuthAccount change module
- Link OAuth to existing account when email matches
- Preserve existing user data (name, etc.)
- Create new user if email doesn't exist
- Validate email is present in OAuth user_info

All tests passing.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 5: Error Handling in AuthController

**Files:**
- Modify or Create: `lib/angle_web/controllers/auth_controller.ex`

**Step 1: Check if AuthController exists**

Run: `ls -la lib/angle_web/controllers/auth_controller.ex`

Expected: File should exist (since auth routes reference it)

**Step 2: Read current AuthController**

Run: `cat lib/angle_web/controllers/auth_controller.ex | head -50`

Expected: Shows the current controller structure

**Step 3: Check AshAuthentication.Phoenix documentation**

AshAuthentication likely handles OAuth callbacks automatically. We need to check if we can customize error handling.

Run: `mix usage_rules.search_docs "oauth error handling" -p ash_authentication`

Expected: Documentation about handling OAuth errors

**Step 4: Add error handling for OAuth failures**

Since OAuth is handled by `AngleWeb.AuthPlug` (forwarded in router), we may need to configure error handling in the plug or add a custom controller action.

Check the current auth plug configuration:

Run: `grep -r "AuthPlug" lib/angle_web/`

Expected: Shows where AuthPlug is defined or configured

Based on typical AshAuthentication setup, OAuth errors are handled by the framework. We can customize error messages by configuring the plug or by adding a custom error handler.

For now, let's verify that flash messages work correctly. If AshAuthentication doesn't provide error handling, we'll need to add a custom callback handler.

**Step 5: Test error handling manually**

This requires manual testing since OAuth errors are hard to simulate in automated tests.

Create a manual test checklist in `docs/plans/manual-testing-checklist.md`:

```markdown
# Google OAuth Manual Testing Checklist

## Prerequisites
- [ ] Google OAuth credentials set in .env
- [ ] Phoenix server running on port 4111
- [ ] Test Google account ready

## Test Cases

### 1. New User Registration
- [ ] Navigate to http://localhost:4111/auth/login
- [ ] Click "Continue with Google"
- [ ] Authorize with Google account (use test account)
- [ ] Verify redirected to /dashboard
- [ ] Verify user is logged in
- [ ] Verify "bidder" role assigned (check in admin or database)

### 2. Account Linking
- [ ] Create user via email/password registration
- [ ] Log out
- [ ] Click "Continue with Google" on login page
- [ ] Use same email address as email/password account
- [ ] Verify logged into existing account (not new account created)
- [ ] Verify original user data preserved (name, etc.)

### 3. Error: Cancel OAuth
- [ ] Click "Continue with Google"
- [ ] On Google consent screen, click "Cancel" or "Deny"
- [ ] Verify redirected back to login page
- [ ] Verify friendly error message displayed (not technical error)
- [ ] Expected message: "Google sign-in was cancelled" or similar

### 4. Error: Network Issues
- [ ] Disconnect from internet
- [ ] Click "Continue with Google"
- [ ] Verify error message displayed
- [ ] Expected message: "Could not connect to Google" or similar

### 5. Session Persistence
- [ ] Sign in with Google
- [ ] Close browser
- [ ] Reopen browser and navigate to app
- [ ] Verify still logged in

## Notes
Record any issues or unexpected behavior here.
```

**Step 6: Verify flash message configuration**

Check that Inertia is configured to pass flash messages to React:

Run: `grep -A 5 "flash" lib/angle_web/controllers/`

Expected: Controllers should be setting flash messages

Run: `grep -A 5 "flash" assets/js/`

Expected: React components should be reading flash messages

**Step 7: Add error handling if needed**

If AshAuthentication doesn't handle errors well, we may need to add a custom plug or controller action. For now, document what needs testing:

Create `docs/plans/oauth-error-handling-notes.md`:

```markdown
# OAuth Error Handling Notes

## Current State

AshAuthentication handles OAuth flow automatically via `AngleWeb.AuthPlug`.

## What Needs Verification

1. **User cancels OAuth consent**
   - Does AshAuthentication redirect back with error?
   - Is error message user-friendly?
   - Is error displayed via flash message?

2. **OAuth provider errors**
   - Network timeouts
   - Invalid credentials
   - Rate limiting

3. **Missing user info**
   - If Google doesn't return email
   - If required fields are missing

## Implementation Plan

After manual testing, if error handling is insufficient:

1. Add custom error handler plug
2. Intercept AshAuthentication errors
3. Set appropriate flash messages
4. Redirect to login with user-friendly messages

## References

- AshAuthentication.Phoenix documentation
- Existing error handling in controllers
- Inertia.js flash message pattern
```

**Step 8: Commit error handling documentation**

```bash
git add docs/plans/manual-testing-checklist.md docs/plans/oauth-error-handling-notes.md
git commit -m "docs: add OAuth error handling checklist and notes

- Manual testing checklist for OAuth flows
- Notes on error handling verification
- Plan for custom error handling if needed

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 6: Verify Tests Pass

**Files:**
- None (verification only)

**Step 1: Run all tests**

Run: `mix test`

Expected: All tests should pass

**Step 2: Run only OAuth tests**

Run: `mix test test/angle/accounts/user_test.exs`

Expected: All OAuth tests should pass

**Step 3: Check test coverage (optional)**

Run: `mix test --cover`

Expected: Shows test coverage percentage

**Step 4: If any tests fail, debug and fix**

If tests fail:

Run: `mix test --failed --trace`

Expected: Shows detailed output for failed tests

Fix issues, then run tests again until all pass.

---

## Task 7: Manual End-to-End Testing

**Files:**
- None (manual testing only)

**Step 1: Set up Google OAuth credentials**

Follow the guide in `docs/setup/google-oauth.md` to:
1. Create Google OAuth credentials in Google Cloud Console
2. Set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET in `.env`
3. Configure redirect URI: `http://localhost:4111/auth/user/google/callback`

**Step 2: Start Phoenix server**

Run: `mix phx.server`

Expected: Server starts on port 4111

**Step 3: Execute manual test checklist**

Work through `docs/plans/manual-testing-checklist.md`:
- [ ] Test new user registration via Google
- [ ] Test account linking
- [ ] Test error cases (cancel consent, etc.)
- [ ] Test session persistence

**Step 4: Document test results**

Add test results to the checklist file, noting any issues found.

**Step 5: Fix any issues found during manual testing**

If issues are discovered:
1. Create failing test (if possible)
2. Implement fix
3. Verify test passes
4. Re-test manually
5. Commit fix

---

## Task 8: Final Verification

**Files:**
- None (verification only)

**Step 1: Run all tests one final time**

Run: `mix test`

Expected: All tests pass with 0 failures

**Step 2: Verify all documentation is complete**

Run: `ls -la docs/setup/google-oauth.md docs/plans/manual-testing-checklist.md`

Expected: Both files exist

**Step 3: Verify environment variables documented**

Run: `grep GOOGLE .env.example`

Expected: Shows GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET

**Step 4: Check git status**

Run: `git status`

Expected: Working tree should be clean (all changes committed)

**Step 5: Review commit history**

Run: `git log --oneline -10`

Expected: Should show commits for:
- Environment documentation
- Setup guide
- Tests
- Implementation
- Manual testing checklist

**Step 6: Push to remote (if ready)**

Run: `git push -u origin feature/google-auth`

Expected: Branch pushed to remote

**Step 7: Create pull request (optional)**

If ready to merge:

Run: `gh pr create --title "feat: complete Google OAuth with account linking" --body "$(cat <<'EOF'
## Summary
- ✅ Account linking (Google OAuth to existing email/password accounts)
- ✅ Environment variable documentation
- ✅ Setup guide for developers
- ✅ Tests for OAuth registration and linking
- ✅ Manual testing completed

## Testing
- All automated tests passing
- Manual testing checklist completed
- Verified new user registration works
- Verified account linking works
- Verified error handling works

## Documentation
- `.env.example` updated with Google OAuth variables
- `docs/setup/google-oauth.md` created with complete setup guide
- Manual testing checklist documented

## References
- Design doc: `docs/plans/2026-02-20-google-oauth-completion-design.md`
- Implementation plan: `docs/plans/2026-02-20-google-oauth-completion-plan.md`

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"`

Expected: Pull request created with link to PR

---

## Success Criteria

Feature is complete when:
- ✅ All automated tests pass
- ✅ Manual testing checklist completed successfully
- ✅ Environment variables documented in `.env.example`
- ✅ Setup guide created at `docs/setup/google-oauth.md`
- ✅ Account linking works (Google OAuth links to existing email/password account)
- ✅ Error handling works (user-friendly messages for OAuth errors)
- ✅ All changes committed to git
- ✅ Pull request created (optional)

## Notes for Implementer

**Important points:**

1. **TDD Approach:** Write tests BEFORE implementation. Make tests fail first, then make them pass.

2. **Account Linking:** The key insight is that if email matches, it's safe to link accounts because the user proved they own the Google account via OAuth.

3. **AshAuthentication:** This framework handles most OAuth complexity. We're adding account linking on top of existing functionality.

4. **Manual Testing Required:** OAuth flows are hard to test automatically. Manual testing is essential.

5. **Error Handling:** AshAuthentication may already handle errors. Verify during manual testing. Only add custom error handling if needed.

6. **Commit Often:** Commit after each task. Small, focused commits are easier to review and debug.

7. **Read Documentation:** Use `mix usage_rules.search_docs` to search AshAuthentication docs before making assumptions.

## Troubleshooting

**Tests fail with "function not found":**
- Check that factory functions exist in `test/support/factory.ex`
- Use `create_user/1` to create test users

**Tests fail with "action not found":**
- Verify `register_with_google` action exists in User resource
- Check action name spelling

**OAuth doesn't work locally:**
- Verify GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET are set in `.env`
- Verify redirect URI in Google Console matches exactly: `http://localhost:4111/auth/user/google/callback`
- Check Phoenix server is running on port 4111 (not 4000)

**Account linking doesn't work:**
- Check that email from Google matches existing account email exactly
- Verify query for existing user is working (check logs)
- Ensure change module is added to action
