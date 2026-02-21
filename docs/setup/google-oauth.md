# Google OAuth Setup Guide

This guide walks you through setting up Google OAuth authentication for the Angle application.

## Prerequisites

- A Google Account
- Access to the [Google Cloud Console](https://console.cloud.google.com/)
- The Angle application running locally (for testing)

## Getting Google OAuth Credentials

### Step 1: Create a Google Cloud Project

1. Go to the [Google Cloud Console](https://console.cloud.google.com/)
2. Click on the project dropdown at the top of the page
3. Click "New Project"
4. Enter a project name (e.g., "Angle Authentication")
5. Click "Create"

### Step 2: Enable Google+ API

1. In your Google Cloud project, navigate to "APIs & Services" > "Library"
2. Search for "Google+ API"
3. Click on "Google+ API"
4. Click "Enable"

Note: While Google+ has been deprecated, the Google+ API is still used for basic profile information in OAuth flows.

### Step 3: Configure OAuth Consent Screen

1. Navigate to "APIs & Services" > "OAuth consent screen"
2. Select "External" user type (unless you have a Google Workspace account)
3. Click "Create"
4. Fill in the required fields:
   - **App name**: Angle
   - **User support email**: Your email address
   - **Developer contact information**: Your email address
5. Click "Save and Continue"
6. On the "Scopes" page, click "Add or Remove Scopes"
7. Add the following scopes:
   - `.../auth/userinfo.email`
   - `.../auth/userinfo.profile`
   - `openid`
8. Click "Update" then "Save and Continue"
9. On the "Test users" page (if in testing mode), add test user emails
10. Click "Save and Continue"
11. Review your settings and click "Back to Dashboard"

### Step 4: Create OAuth Client ID

1. Navigate to "APIs & Services" > "Credentials"
2. Click "Create Credentials" > "OAuth client ID"
3. Select "Web application" as the application type
4. Enter a name (e.g., "Angle Web Client")
5. Under "Authorized redirect URIs", add:
   - For local development: `http://localhost:4111/auth/user/google/callback`
   - For production: `https://yourdomain.com/auth/user/google/callback`
6. Click "Create"
7. Copy the **Client ID** and **Client Secret** - you'll need these for the next step

## Local Development Setup

### Step 1: Set Environment Variables

Create or update your `.env` file in the project root:

```bash
# Google OAuth Configuration
GOOGLE_CLIENT_ID=your_client_id_here.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your_client_secret_here
GOOGLE_REDIRECT_URI=http://localhost:4111/auth/user/google/callback
```

Replace `your_client_id_here` and `your_client_secret_here` with the values from Step 4 above.

### Step 2: Load Environment Variables

If you're using `direnv` or similar, reload your environment:

```bash
direnv allow
```

Or source the .env file manually if needed.

### Step 3: Restart Your Application

```bash
mix phx.server
```

### Step 4: Test the Integration

1. Navigate to `http://localhost:4111/sign-in`
2. Click "Continue with Google"
3. You should be redirected to Google's OAuth consent screen
4. Sign in with your Google account
5. Grant the requested permissions
6. You should be redirected back to your application and logged in

### Step 5: Verify User Creation

Check that a new user was created in your database:

```elixir
# In iex -S mix phx.server
Angle.Accounts.User
|> Ash.Query.filter(email == "your.google.email@gmail.com")
|> Ash.read!()
```

## Production Deployment

### Step 1: Set Production Environment Variables

Set the following environment variables in your production environment (e.g., Fly.io secrets, Heroku config vars, etc.):

```bash
GOOGLE_CLIENT_ID=your_client_id_here.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your_client_secret_here
GOOGLE_REDIRECT_URI=https://yourdomain.com/auth/user/google/callback
```

### Step 2: Update OAuth Client Authorized Redirect URIs

1. Go back to the Google Cloud Console
2. Navigate to "APIs & Services" > "Credentials"
3. Click on your OAuth 2.0 Client ID
4. Under "Authorized redirect URIs", ensure your production URL is listed:
   - `https://yourdomain.com/auth/user/google/callback`
5. Click "Save"

### Step 3: Publish Your OAuth App (Optional)

If your app is in testing mode, you'll need to publish it for general use:

1. Navigate to "APIs & Services" > "OAuth consent screen"
2. Click "Publish App"
3. Follow the verification process if required

Note: Unverified apps have user limits and show a warning screen to users.

### Step 4: Test Production Login

1. Navigate to your production login page
2. Click "Continue with Google"
3. Complete the OAuth flow
4. Verify successful login

## How It Works

### New User Registration

1. User clicks "Continue with Google"
2. User is redirected to Google's OAuth consent screen
3. User grants permissions
4. Google redirects back with an authorization code
5. Application exchanges code for access token
6. Application fetches user profile from Google
7. Application checks if user exists by email
8. If new user: creates account with email, name, and avatar
9. User is signed in and redirected to dashboard

### Account Linking

If a user already exists with the same email (e.g., they previously signed up with email/password):

1. The Google OAuth flow will automatically link to the existing account
2. The user's authentication tokens are created/updated
3. User is signed in to their existing account

This is handled by `AshAuthentication.Strategy.OAuth2.IdentityChange`.

### Error Handling

Common errors and their causes:

- **"OAuth2 callback error"**: Issue with redirect URI configuration or OAuth client setup
- **"Email already in use"**: Attempted to create account but email exists (shouldn't happen with proper identity linking)
- **"Invalid credentials"**: OAuth token is invalid or expired

## Troubleshooting

### "Redirect URI mismatch" error

**Cause**: The redirect URI in your request doesn't match any authorized redirect URIs in your Google OAuth client.

**Solution**:
1. Check that `GOOGLE_REDIRECT_URI` matches exactly what's configured in Google Cloud Console
2. Ensure protocol (http/https), domain, port, and path all match exactly
3. No trailing slashes in redirect URIs

### "Access blocked: This app's request is invalid"

**Cause**: OAuth consent screen is not properly configured or missing required scopes.

**Solution**:
1. Complete the OAuth consent screen configuration in Step 3 above
2. Ensure required scopes are added
3. If app is in testing mode, ensure test users are added

### User is created but name/avatar are missing

**Cause**: Google API didn't return profile information or scopes are insufficient.

**Solution**:
1. Verify the Google+ API is enabled
2. Check that required scopes are configured in OAuth consent screen
3. Test with a different Google account

### Cannot sign in after initial setup

**Cause**: Environment variables not loaded or incorrect.

**Solution**:
1. Verify `.env` file exists and is properly formatted
2. Restart your Phoenix server
3. Check `System.get_env("GOOGLE_CLIENT_ID")` in IEx

## Security Notes

- Never commit your `.env` file or expose your `GOOGLE_CLIENT_SECRET`
- Use different OAuth clients for development and production
- Rotate your client secret if it's ever exposed
- Regularly review authorized redirect URIs to prevent OAuth hijacking
- Consider implementing additional security measures like PKCE for enhanced security
