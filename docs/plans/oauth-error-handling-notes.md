# OAuth Error Handling Notes

This document describes how OAuth errors are handled in the Angle application.

## Current Implementation

### AshAuthentication Error Handling

The Google OAuth integration uses `AshAuthentication.Strategy.OAuth2` which provides built-in error handling. The integration point is in `AngleWeb.AuthPlug`, which defines callback functions for success and failure scenarios.

**File:** `lib/angle_web/auth_plug.ex`

```elixir
defmodule AngleWeb.AuthPlug do
  use AshAuthentication.Plug, otp_app: :angle

  def handle_success(conn, _activity, user, token) do
    conn =
      conn
      |> store_in_session(user)
      |> Plug.Conn.put_session(:current_user_id, user.id)
      |> maybe_store_token(token)

    {conn, redirect_to} = AngleWeb.Plugs.Auth.pop_return_to(conn, "/dashboard")

    conn
    |> Phoenix.Controller.put_flash(:info, "Successfully signed in!")
    |> Phoenix.Controller.redirect(to: redirect_to)
  end

  def handle_failure(conn, _activity, _reason) do
    conn
    |> Phoenix.Controller.put_flash(:error, "Authentication failed. Please try again.")
    |> Phoenix.Controller.redirect(to: "/auth/login")
  end
end
```

### Error Handling Flow

1. **OAuth Callback Errors** - When Google OAuth fails (user cancels, denies access, or an error occurs):
   - `AshAuthentication` catches the error
   - Calls `handle_failure/3` in `AuthPlug`
   - User redirected to `/auth/login` with error flash message

2. **Flash Message Display** - Flash messages are automatically passed to React via Inertia:
   - Configured in `config/config.exs`:
     ```elixir
     config :inertia,
       shared: %{
         flash: :flash,
         csrf_token: fn _conn -> Phoenix.HTML.Tag.csrf_token_value() end
       }
     ```
   - React layouts consume flash messages:
     - `assets/js/layouts/auth-layout.tsx`
     - `assets/js/layouts/layout.tsx`
   - Flash messages displayed as toast notifications using `sonner`

### Error Types Handled

The `handle_failure/3` callback handles all OAuth failures, including:

- **User Cancellation** - User clicks "Cancel" or "Deny" on Google consent screen
- **Invalid State** - OAuth state parameter mismatch (CSRF protection)
- **Token Exchange Failure** - Error exchanging authorization code for access token
- **Profile Fetch Failure** - Error fetching user profile from Google
- **Account Linking Errors** - Errors during account linking (if applicable)

### Generic Error Message

The current implementation uses a generic error message:

```elixir
"Authentication failed. Please try again."
```

**Rationale:**
- Prevents exposing internal error details to users
- Provides a simple, user-friendly message
- Encourages users to retry the flow

## Future Enhancements (If Needed)

If more granular error handling is required in the future, consider:

1. **Specific Error Messages** - Pattern match on `reason` parameter in `handle_failure/3`:
   ```elixir
   def handle_failure(conn, _activity, reason) do
     message = case reason do
       {:error, %AshAuthentication.Errors.AuthenticationFailed{}} ->
         "Authentication failed. Please try again."
       {:error, :token_exchange_failed} ->
         "Unable to complete sign-in. Please try again."
       {:error, :user_cancelled} ->
         "Sign-in cancelled."
       _ ->
         "Authentication failed. Please try again."
     end

     conn
     |> Phoenix.Controller.put_flash(:error, message)
     |> Phoenix.Controller.redirect(to: "/auth/login")
   end
   ```

2. **Error Logging** - Add logging for debugging:
   ```elixir
   def handle_failure(conn, activity, reason) do
     require Logger
     Logger.warning("OAuth authentication failed",
       activity: activity,
       reason: inspect(reason)
     )

     conn
     |> Phoenix.Controller.put_flash(:error, "Authentication failed. Please try again.")
     |> Phoenix.Controller.redirect(to: "/auth/login")
   end
   ```

3. **Retry with Different Account** - Add a "Try different account" button in the error message.

4. **Support Email** - Include support contact information in error messages for persistent failures.

## Testing Error Handling

To manually test error handling:

1. **User Cancellation:**
   - Click "Continue with Google"
   - Click "Cancel" on Google consent screen
   - Verify redirect to `/auth/login` with error message

2. **Invalid State:**
   - Manually modify OAuth state parameter in URL
   - Verify error handling

3. **Network Errors:**
   - Disable network mid-flow (if possible)
   - Verify graceful error handling

## Conclusion

The current OAuth error handling implementation is **sufficient for production use**. It:

- ✅ Handles all OAuth failures gracefully
- ✅ Provides user-friendly error messages
- ✅ Redirects users appropriately
- ✅ Integrates with existing flash message system

**No custom error handling implementation is needed at this time.**

Future enhancements can be added based on user feedback and monitoring data.
