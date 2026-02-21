# Google OAuth Completion Design

**Date:** 2026-02-20
**Status:** Approved
**Approach:** Minimal Completion + Account Linking

## Goal

Complete the existing Google OAuth implementation (~90% done) with account linking support, environment documentation, error handling, and basic testing.

## Current State

**What's already implemented:**
- ✅ Google OAuth strategy configured in User resource (`lib/angle/accounts/user.ex`)
- ✅ `register_with_google` action with user_info and oauth_tokens arguments
- ✅ Automatic "bidder" role assignment on registration
- ✅ OAuth secrets management via `Angle.Secrets` module
- ✅ OAuth callback routes (`/auth/*` → `AngleWeb.AuthPlug`)
- ✅ Frontend "Continue with Google" buttons on login and register pages
- ✅ OAuth tokens stored in User resource

**What's missing:**
- ❌ Account linking (connect Google to existing email/password account)
- ❌ Environment variable documentation
- ❌ Error handling for OAuth failures
- ❌ Testing for OAuth flow
- ❌ Setup documentation

## Architecture

### High-Level Flow

1. **User clicks "Continue with Google"** → Frontend redirects to `/auth/google`
2. **Google OAuth consent screen** → User authorizes application
3. **Google callback** → Redirects to `/auth/user/google/callback` with OAuth code
4. **AshAuthentication processes callback** → Exchanges code for tokens, fetches user info
5. **Account creation or linking** → `register_with_google` action handles both scenarios
6. **Session creation** → User logged in, redirected to `/dashboard`

### Account Linking Strategy

**Scenario 1: New user (email doesn't exist)**
- Create new User record with Google OAuth data
- Assign "bidder" role automatically
- Store OAuth tokens
- Create session

**Scenario 2: Existing user (email matches)**
- Link Google OAuth identity to existing account
- Update user record with OAuth tokens (preserve existing data)
- Create session with existing user

**Key insight:** Since the user proved they own the Google account (via OAuth), and the email matches, auto-linking is safe. No additional confirmation needed.

### Technical Decisions

- **Framework:** AshAuthentication (already configured) handles OAuth flow and security
- **Account linking:** Custom logic in `register_with_google` action
- **Error handling:** Inertia flash messages for user feedback
- **Testing:** Unit tests + manual end-to-end testing
- **Documentation:** Environment setup guide for Google OAuth credentials

## Components & Files

### Backend Changes

#### 1. `lib/angle/accounts/user.ex` (modify)
**Purpose:** Add account linking logic to OAuth registration

**Changes:**
- Modify `register_with_google` action or add preparation
- Check if user with OAuth email already exists
- If exists: update existing user with OAuth tokens (link account)
- If new: create new user (current behavior)
- Handle both cases gracefully

#### 2. `lib/angle_web/controllers/auth_controller.ex` (modify)
**Purpose:** Handle OAuth errors with user-friendly messages

**Changes:**
- Add error handling for OAuth callback failures
- Set flash error messages
- Redirect to appropriate page (`/auth/login` or `/auth/register`)

#### 3. `.env.example` (modify)
**Purpose:** Document required environment variables

**Add:**
```bash
# Google OAuth (required for social login)
GOOGLE_CLIENT_ID=your_client_id_here
GOOGLE_CLIENT_SECRET=your_client_secret_here
```

#### 4. `docs/setup/google-oauth.md` (create)
**Purpose:** Setup guide for developers

**Contents:**
- How to create Google OAuth credentials
- Where to configure redirect URIs in Google Console
- Environment variable setup for local development
- Testing instructions

### Frontend Changes

#### 5. `assets/js/features/auth/components/login-form.tsx` (verify)
**Purpose:** Verify error handling displays correctly

**Action:**
- Google button already implemented
- Verify flash error messages display properly
- No code changes expected (unless error display is broken)

#### 6. `assets/js/features/auth/components/register-form.tsx` (verify)
**Purpose:** Same as login form

**Action:**
- Verify flash error messages display properly

### Tests

#### 7. `test/angle/accounts/user_test.exs` (create/modify)
**Purpose:** Automated testing for OAuth registration and linking

**Test cases:**
- Google OAuth registration for new user
- Account linking when email exists
- OAuth failure cases (missing email, invalid data)
- Role assignment verification

## Data Flow

### Happy Path: New User

```
User clicks Google button
  ↓
router.visit("/auth/google")
  ↓
Redirect to Google OAuth consent screen
  ↓
User authorizes
  ↓
Google redirects to /auth/user/google/callback?code=...
  ↓
AshAuthentication exchanges code for tokens
  ↓
Fetch user info from Google (email, name, picture)
  ↓
register_with_google action creates User
  ↓
Assign "bidder" role (automatic)
  ↓
Create session
  ↓
Redirect to /dashboard
```

### Happy Path: Account Linking

```
User clicks Google button (user already has email/password account)
  ↓
[Steps 1-5 same as above]
  ↓
register_with_google detects email exists
  ↓
Link Google OAuth to existing account
  ↓
Update user with OAuth tokens (preserve existing data)
  ↓
Create session
  ↓
Redirect to /dashboard
```

### Error Path

```
User clicks Google button
  ↓
[Steps 1-3 same as above]
  ↓
User denies consent OR OAuth error occurs
  ↓
AshAuthentication catches error
  ↓
AuthController handles error
  ↓
Set flash message: "Could not sign in with Google. Please try again."
  ↓
Redirect to /auth/login (or /auth/register)
```

### Data Stored

**In User record:**
- Email (from Google)
- Name (from Google)
- Profile picture URL (optional)
- OAuth tokens (access_token, refresh_token)
- Role assignment (bidder)

**In session:**
- User ID
- Authentication token

## Error Handling

### OAuth Provider Errors

| Error | User Message | Action |
|-------|-------------|--------|
| User denies consent | "Google sign-in was cancelled" | Redirect to login |
| Invalid credentials | "Authentication failed. Please try again." | Redirect to login |
| Network timeout | "Could not connect to Google. Please try again." | Redirect to login |
| Missing email | "Could not retrieve your email from Google" | Redirect to login + log error |

### Account Linking Scenarios

| Scenario | Behavior |
|----------|----------|
| Email exists with password | Auto-link Google OAuth (safe - user proved ownership) |
| Email exists with other OAuth | Link Google as well (multiple OAuth providers allowed) |
| Invalid email format | Should never happen (Google validates), but catch anyway |

### Implementation Details

- **User feedback:** Inertia flash messages (already configured)
- **Server logging:** Log all OAuth errors for debugging
- **Error messages:** User-friendly, non-technical
- **Security:** Never expose internal error details

### Out of Scope (YAGNI)

- OAuth token refresh logic
- Rate limiting (Phoenix has built-in protection)
- Advanced account merging (e.g., transferring bids)
- Security audit (AshAuthentication handles most concerns)

## Testing Strategy

### Manual End-to-End Testing (Required)

**Prerequisites:**
1. Set up Google OAuth credentials in `.env`
2. Configure redirect URI in Google Console: `http://localhost:4111/auth/user/google/callback`

**Test checklist:**
- [ ] New user registration via Google
- [ ] Verify user redirected to dashboard
- [ ] Verify "bidder" role assigned
- [ ] Account linking: Create email/password account, then sign in with Google (same email)
- [ ] Verify existing account data preserved after linking
- [ ] Cancel OAuth consent → verify error message
- [ ] Invalid credentials → verify error message
- [ ] Session persistence after OAuth login

### Automated Tests

**Unit tests** (`test/angle/accounts/user_test.exs`):
- Test `register_with_google` creates new user with valid data
- Test account linking when email exists
- Test error handling for missing email
- Test role assignment

**Integration tests** (optional - can add later):
- Mock OAuth provider responses
- Test full callback flow
- Test session creation

### Out of Scope

- OAuth token refresh testing
- Performance testing
- Security penetration testing
- Advanced account merging scenarios

## Setup Documentation

**To be created:** `docs/setup/google-oauth.md`

**Contents:**

1. **Getting Google OAuth Credentials**
   - Go to Google Cloud Console
   - Create OAuth 2.0 Client ID
   - Configure authorized redirect URIs

2. **Environment Configuration**
   - Copy `.env.example` to `.env`
   - Set `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET`
   - Set `GOOGLE_OAUTH_REDIRECT_URI` if needed (defaults to localhost:4111)

3. **Local Development**
   - Ensure Phoenix server runs on port 4111
   - Redirect URI must match Google Console configuration
   - Test with real Google account

4. **Production Deployment**
   - Set environment variables in production
   - Update redirect URI to production domain
   - Verify SSL certificate (Google requires HTTPS in production)

## Success Criteria

**Feature is complete when:**
- ✅ New users can register via Google OAuth
- ✅ Existing users can link Google to their account
- ✅ OAuth errors display user-friendly messages
- ✅ Environment variables documented
- ✅ Setup guide created
- ✅ Basic tests pass
- ✅ Manual testing checklist complete

## Timeline

**Estimated effort:** 2-3 hours

**Breakdown:**
- Account linking logic: 45 minutes
- Error handling: 30 minutes
- Documentation: 30 minutes
- Tests: 45 minutes
- Manual testing: 30 minutes

## References

- AshAuthentication OAuth documentation
- Google OAuth 2.0 documentation
- Existing User resource: `lib/angle/accounts/user.ex`
- Existing secrets config: `lib/angle/secrets.ex`
