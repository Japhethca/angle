# Security Audit Report - Angle Authentication System

**Date:** 2025-10-03
**Auditor:** Claude Code
**Scope:** Authentication and authorization implementation

## Executive Summary

This security audit examined the authentication and authorization implementation of the Angle auction platform. The application uses AshAuthentication with session-based authentication and JWT tokens. Overall, the implementation follows security best practices with several areas of strength and some recommendations for improvement.

**Overall Security Rating:** ✅ Good (with recommendations)

## Key Findings

### ✅ Strengths

1. **Password Security**
   - Uses bcrypt for password hashing (via AshAuthentication)
   - Minimum password length of 8 characters enforced
   - Password confirmation required for registration and reset
   - Sensitive fields marked with `sensitive?: true`

2. **CSRF Protection**
   - CSRF protection enabled in browser pipeline (`protect_from_forgery`)
   - CSRF tokens included in page meta tags
   - Phoenix framework provides automatic CSRF validation

3. **Token Management**
   - JWT tokens properly signed with configurable secret
   - Token storage enabled (`store_all_tokens? true`)
   - Token presence required for authentication
   - Automatic token invalidation on password change

4. **Email Confirmation**
   - User email confirmation required (`confirm_on_create? true`)
   - Confirmation tokens properly validated
   - Token expiration handling implemented

5. **Authorization**
   - Role-Based Access Control (RBAC) properly implemented
   - Ash policies restrict access to user data
   - Users can only read/update their own records
   - Permission checks through roles and permissions

6. **Session Security**
   - Session-based authentication with secure session storage
   - Session cleared on logout
   - Failed user load clears session

## ⚠️ Security Concerns & Recommendations

### 1. 🔴 CRITICAL: Hardcoded Secrets in Development

**Issue:** `config/dev.exs` contains hardcoded secrets:
- Line 24: `secret_key_base`
- Line 66: `token_signing_secret`

**Location:** `/Users/chidex/sources/mine/angle/config/dev.exs:24,66`

**Risk:** If these values are reused in production, it would be a critical vulnerability.

**Recommendation:**
```elixir
# config/dev.exs
config :angle, AngleWeb.Endpoint,
  secret_key_base: System.get_env("SECRET_KEY_BASE") ||
    "fHR59CxegCaUFYPgnmaJowYDZHBMTQuzKFfyTeYS0E5vKza0t6QRBtY6/1Kb5JLl"

config :angle,
  token_signing_secret: System.get_env("TOKEN_SIGNING_SECRET") ||
    "bYcdGFFVAhW6tgIeA6Dv6WnRnPRWUyhJ"
```

**Status:** ✅ VERIFIED - Production uses environment variables (runtime.exs:46-52, 70-73)

### 2. 🟡 MEDIUM: No Rate Limiting

**Issue:** No rate limiting found on authentication endpoints.

**Risk:** Brute force attacks on login, registration, password reset endpoints.

**Affected Endpoints:**
- `/auth/login` - Login attempts
- `/auth/register` - Registration spam
- `/auth/forgot-password` - Email enumeration
- `/auth/reset-password` - Token brute force

**Recommendation:** Implement rate limiting using a library like `plug_attack` or `hammer`:

```elixir
# Add to mix.exs
{:hammer, "~> 6.1"}

# Create lib/angle_web/plugs/rate_limiter.ex
defmodule AngleWeb.Plugs.RateLimiter do
  import Plug.Conn

  def rate_limit_auth(conn, _opts) do
    case Hammer.check_rate("auth:#{get_ip(conn)}", 60_000, 5) do
      {:allow, _count} ->
        conn
      {:deny, _limit} ->
        conn
        |> put_status(:too_many_requests)
        |> Phoenix.Controller.put_flash(:error, "Too many attempts. Please try again later.")
        |> Phoenix.Controller.redirect(to: "/")
        |> halt()
    end
  end

  defp get_ip(conn), do: conn.remote_ip |> Tuple.to_list() |> Enum.join(".")
end

# Update router.ex
pipeline :auth_rate_limited do
  plug :rate_limit_auth
end

scope "/auth", AngleWeb do
  pipe_through [:browser, :auth_rate_limited]
  # ... auth routes
end
```

### 3. 🟡 MEDIUM: Email Enumeration Possible

**Issue:** Registration and login may reveal whether an email exists.

**Location:** `/Users/chidex/sources/mine/angle/lib/angle_web/controllers/auth_controller.ex:8-36`

**Risk:** Attackers can enumerate valid email addresses.

**Current Mitigation:** Password reset properly prevents enumeration (line 84-93).

**Recommendation:**
- Ensure registration errors are generic: "Unable to create account" instead of "Email already exists"
- Login errors already use generic message: "Invalid email or password" ✅

### 4. 🟡 MEDIUM: Debug Logging in Production

**Issue:** Extensive debug logging with `Logger.error` for authentication flow.

**Locations:**
- `lib/angle_web/controllers/auth_controller.ex:9,13,21,29,30`
- `lib/angle_web/plugs/auth.ex:38,42,46,50,70,79,86,90,100,113,140`

**Risk:** Sensitive information logged (user IDs, authentication status).

**Recommendation:** Use conditional compilation for debug logs:

```elixir
defmodule AngleWeb.Plugs.Auth do
  require Logger

  if Mix.env() == :dev do
    defp debug_log(message), do: Logger.debug(message)
  else
    defp debug_log(_message), do: :ok
  end

  # Then replace Logger.error("DEBUG AUTH: ...") with debug_log("...")
end
```

### 5. 🟢 LOW: Session Fixation Protection

**Status:** ✅ PARTIALLY MITIGATED

**Current Implementation:**
- Sessions cleared on logout ✅
- Sessions cleared on failed user load ✅

**Enhancement:** Regenerate session ID on login for stronger protection:

```elixir
# In auth_controller.ex do_login
{:ok, %{user: user, metadata: %{token: token}}} ->
  conn
  |> renew_session()  # Add this
  |> put_session(:current_user_id, user.id)
  |> put_session(:auth_token, token)
  # ...

defp renew_session(conn) do
  conn
  |> configure_session(renew: true)
  |> clear_session()
end
```

### 6. 🟢 LOW: Password Strength Requirements

**Current:** Minimum 8 characters

**Location:** `/Users/chidex/sources/mine/angle/lib/angle/accounts/user.ex:92,165,224`

**Recommendation:** Consider strengthening password requirements:

```elixir
# Add to User resource
validate fn changeset, context ->
  case Ash.Changeset.get_argument(changeset, :password) do
    nil -> {:ok, changeset}
    password ->
      cond do
        String.length(password) < 12 ->
          {:error, field: :password, message: "must be at least 12 characters"}

        not Regex.match?(~r/[A-Z]/, password) ->
          {:error, field: :password, message: "must contain at least one uppercase letter"}

        not Regex.match?(~r/[a-z]/, password) ->
          {:error, field: :password, message: "must contain at least one lowercase letter"}

        not Regex.match?(~r/[0-9]/, password) ->
          {:error, field: :password, message: "must contain at least one number"}

        true ->
          {:ok, changeset}
      end
  end
end
```

### 7. 🟢 LOW: Token Expiration

**Issue:** No explicit JWT token expiration configured.

**Location:** `/Users/chidex/sources/mine/angle/lib/angle/accounts/user.ex:30-36`

**Recommendation:** Add token TTL:

```elixir
tokens do
  enabled? true
  token_resource Angle.Accounts.Token
  signing_secret Angle.Secrets
  store_all_tokens? true
  require_token_presence_for_authentication? true
  access_token_lifetime_minutes 60  # Add this
  refresh_token_lifetime_days 30     # Add this
end
```

### 8. 🟢 LOW: Missing Security Headers

**Recommendation:** Add security headers to endpoint configuration:

```elixir
# config/config.exs or endpoint.ex
plug Plug.Static,
  # ... existing config

plug :put_secure_browser_headers, %{
  "x-frame-options" => "DENY",
  "x-content-type-options" => "nosniff",
  "x-xss-protection" => "1; mode=block",
  "referrer-policy" => "strict-origin-when-cross-origin",
  "permissions-policy" => "geolocation=(), microphone=(), camera=()"
}
```

## Vulnerability Assessment

### SQL Injection
**Status:** ✅ PROTECTED
**Reason:** All database queries use Ash/Ecto parameterized queries. No raw SQL found.

### XSS (Cross-Site Scripting)
**Status:** ✅ PROTECTED
**Reason:** React automatically escapes output. Phoenix templates use HEEx with automatic escaping.

### CSRF (Cross-Site Request Forgery)
**Status:** ✅ PROTECTED
**Reason:** Phoenix CSRF protection enabled in browser pipeline.

### Session Hijacking
**Status:** ✅ MOSTLY PROTECTED
**Enhancement:** Add session regeneration on login (recommendation #5).

### Password Storage
**Status:** ✅ SECURE
**Reason:** Bcrypt hashing via AshAuthentication with proper salt.

### Authentication Bypass
**Status:** ✅ PROTECTED
**Reason:** Proper session validation, token verification, and Ash policies.

### Authorization Issues
**Status:** ✅ PROTECTED
**Reason:** Comprehensive Ash policies restrict resource access.

## API Security

### REST API (JSON:API)
- ✅ Requires JWT token via `Authorization: Bearer <token>` header
- ✅ Token validation in `validate_api_token` plug
- ✅ Returns 401 Unauthorized for invalid/missing tokens

### GraphQL API
- ✅ Requires JWT token via `api_auth` pipeline
- ✅ Same token validation as REST API

### RPC Endpoints
- ⚠️ Session-based authentication (relies on browser cookies)
- ✅ CSRF protection from browser pipeline
- 🟡 Consider adding explicit auth checks for sensitive RPC operations

## Frontend Security

### Token Handling
**Status:** ✅ GOOD
**Details:**
- No JWT tokens exposed in frontend code
- Authentication state passed via Inertia props
- Uses HTTP-only session cookies (not accessible via JavaScript)

### Auth Context
**Location:** `/Users/chidex/sources/mine/angle/assets/js/contexts/auth-context.tsx`

**Status:** ✅ SECURE
- No sensitive data storage in localStorage/sessionStorage
- Role/permission checks performed server-side first
- Frontend checks are for UI only, not security

## Production Checklist

Before deploying to production, ensure:

- [ ] All environment variables properly set:
  - [ ] `SECRET_KEY_BASE` (unique, 64+ chars)
  - [ ] `TOKEN_SIGNING_SECRET` (unique, 32+ chars)
  - [ ] `DATABASE_URL` (secure connection string)

- [ ] SSL/TLS enabled:
  - [ ] `force_ssl: [hsts: true]` in production endpoint config
  - [ ] Valid SSL certificate

- [ ] Email configuration:
  - [ ] SMTP credentials secured
  - [ ] FROM_EMAIL set to real domain
  - [ ] Email templates reviewed

- [ ] Rate limiting implemented (recommendation #2)

- [ ] Debug logging disabled (recommendation #4)

- [ ] Security headers configured (recommendation #8)

- [ ] Session configuration:
  - [ ] Secure session cookie settings
  - [ ] Session timeout configured

- [ ] Monitoring:
  - [ ] Failed login attempts logged
  - [ ] Unusual activity alerts
  - [ ] Token validation failures tracked

## Code Quality Observations

### Positive
- Clean separation of concerns (controllers, plugs, resources)
- Proper use of AshAuthentication framework
- Comprehensive error handling in confirmation flow
- Well-structured RBAC with roles and permissions

### Areas for Improvement
- Remove or conditionalize debug logging statements
- Add rate limiting to prevent abuse
- Consider session ID regeneration on login
- Add comprehensive security headers

## Conclusion

The Angle authentication system demonstrates solid security practices with proper use of the AshAuthentication framework. The implementation correctly handles password hashing, CSRF protection, token management, and authorization.

The main recommendations focus on operational security (rate limiting, debug logging) rather than fundamental design flaws. Implementing the MEDIUM priority recommendations (#2, #3, #4) will significantly strengthen the application's security posture.

**Recommended Next Steps:**
1. Implement rate limiting on authentication endpoints (Priority: HIGH)
2. Remove/conditionalize debug logging (Priority: HIGH)
3. Add session regeneration on login (Priority: MEDIUM)
4. Configure token expiration (Priority: MEDIUM)
5. Strengthen password requirements (Priority: LOW)
6. Add security headers (Priority: LOW)

---

**Report Version:** 1.0
**Last Updated:** 2025-10-03
