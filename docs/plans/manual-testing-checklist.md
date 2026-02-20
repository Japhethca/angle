# Google OAuth Manual Testing Checklist

This checklist guides you through manual end-to-end testing of the Google OAuth integration.

## Prerequisites

- [ ] Phoenix server running on port 4113
- [ ] Google OAuth credentials configured in `.env`
- [ ] Browser with dev tools open

## Test Case 1: New User Sign Up with Google

**Goal:** Verify that a new user can sign up using Google OAuth.

**Steps:**

1. [ ] Navigate to `http://localhost:4113/auth/login`
2. [ ] Click "Continue with Google" button
3. [ ] Select a Google account (use an account NOT previously used with the app)
4. [ ] Verify redirect to dashboard (`http://localhost:4113/dashboard`)
5. [ ] Verify flash message: "Successfully signed in!"
6. [ ] Open browser dev tools → Application → Cookies
7. [ ] Verify `_angle_key` session cookie exists

**Verify in Database:**

```elixir
# In IEx connected to the server
user = Angle.Accounts.User |> Ash.Query.filter(email == "your-test-email@gmail.com") |> Ash.read_one!()
user.authentication_strategies  # Should include "google"
```

**Expected Results:**

- ✅ New user created in database
- ✅ User redirected to dashboard
- ✅ Session cookie set
- ✅ User has `authentication_strategies: ["google"]`

---

## Test Case 2: Existing User Sign In with Google

**Goal:** Verify that an existing Google OAuth user can sign in again.

**Steps:**

1. [ ] Sign out if currently logged in
2. [ ] Navigate to `http://localhost:4113/auth/login`
3. [ ] Click "Continue with Google" button
4. [ ] Select the same Google account used in Test Case 1
5. [ ] Verify redirect to dashboard
6. [ ] Verify flash message: "Successfully signed in!"

**Expected Results:**

- ✅ Same user logged in (no duplicate created)
- ✅ User redirected to dashboard
- ✅ Session cookie set

---

## Test Case 3: Return URL Preservation

**Goal:** Verify that the `return_to` parameter is preserved through the OAuth flow.

**Steps:**

1. [ ] Sign out if currently logged in
2. [ ] Navigate to `http://localhost:4113/auth/login?return_to=/store/dashboard`
3. [ ] Click "Continue with Google" button
4. [ ] Complete Google OAuth flow
5. [ ] Verify redirect to `/store/dashboard` (not `/dashboard`)

**Expected Results:**

- ✅ User redirected to the originally requested URL (`/store/dashboard`)

---

## Test Case 4: OAuth Error Handling

**Goal:** Verify that OAuth errors are handled gracefully.

**Steps:**

1. [ ] Navigate to `http://localhost:4113/auth/login`
2. [ ] Click "Continue with Google" button
3. [ ] On the Google consent screen, click "Cancel" or "Deny"
4. [ ] Verify redirect back to `/auth/login`
5. [ ] Verify flash message: "Authentication failed. Please try again."

**Expected Results:**

- ✅ User redirected to login page
- ✅ Error message displayed
- ✅ No error logged in Phoenix logs (unless debugging)

---

## Test Case 5: Account Linking (Existing Email User)

**Goal:** Verify that a user who signed up with email/password can link their Google account.

**Steps:**

1. [ ] Create a user with email/password (use the sign-up form)
2. [ ] Sign out
3. [ ] Navigate to `http://localhost:4113/auth/login`
4. [ ] Click "Continue with Google" button
5. [ ] Use the same email address as the email/password account
6. [ ] Verify account linking happens correctly

**Verify in Database:**

```elixir
user = Angle.Accounts.User |> Ash.Query.filter(email == "your-test-email@gmail.com") |> Ash.read_one!()
user.authentication_strategies  # Should include both "password" and "google"
```

**Expected Results:**

- ✅ Google account linked to existing user
- ✅ User can sign in with either method
- ✅ `authentication_strategies` includes both `"password"` and `"google"`

---

## Test Case 6: Session Persistence

**Goal:** Verify that the session persists across page refreshes.

**Steps:**

1. [ ] Sign in with Google OAuth
2. [ ] Refresh the page
3. [ ] Verify you remain logged in
4. [ ] Navigate to a protected route (e.g., `/store/dashboard`)
5. [ ] Verify you can access it without re-authentication

**Expected Results:**

- ✅ Session persists across page refreshes
- ✅ Protected routes remain accessible

---

## Test Case 7: Sign Out

**Goal:** Verify that sign out works correctly.

**Steps:**

1. [ ] Sign in with Google OAuth
2. [ ] Click the sign-out button (in the user menu)
3. [ ] Verify redirect to login page or home page
4. [ ] Attempt to navigate to a protected route (e.g., `/store/dashboard`)
5. [ ] Verify redirect to login page with `return_to` parameter

**Expected Results:**

- ✅ User signed out successfully
- ✅ Session cookie cleared
- ✅ Cannot access protected routes

---

## Post-Testing Verification

After completing all test cases:

- [ ] Review Phoenix logs for any errors or warnings
- [ ] Verify no duplicate user accounts created
- [ ] Verify database integrity (no orphaned records)
- [ ] Test on multiple browsers (Chrome, Firefox, Safari)

---

## Notes

- **Browser Cache:** If you encounter issues, try clearing browser cache and cookies.
- **Session Issues:** If sessions aren't persisting, check that `_angle_key` cookie has correct `HttpOnly`, `Secure`, and `SameSite` attributes.
- **Redirect Issues:** If redirects aren't working, check Phoenix logs for router errors.
