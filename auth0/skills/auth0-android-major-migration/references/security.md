# Security Checklist — Auth0.Android Migration

Security invariants that MUST be preserved during any major version migration. Verify each item after the migration build is green.

---

## Non-Negotiable Invariants

These must hold true before and after migration. If any are violated, the migration has a security bug.

### 1. No Secrets in Source Code

```text
[ ] No client_secret in any Kotlin/Java/Gradle/XML file (native apps use PKCE, not secrets)
[ ] No hardcoded tokens or API keys
[ ] Auth0 domain and client ID live in strings.xml (public config, not secrets) — not hardcoded in source
[ ] No Management API token embedded in the app (see §7.2 — Management API moves to a backend)
[ ] No tokens logged to Logcat in production builds
```

**Verification:**

```bash
grep -rniE "client_secret|api_key|apikey|secret_key" \
  --include="*.kt" --include="*.java" --include="*.xml" --include="*.gradle" --include="*.kts" .
```

### 2. Secure Token Storage

```text
[ ] Credentials stored via SecureCredentialsManager (encrypted at rest) — not plain SharedPreferences, not files
[ ] No tokens written to plain SharedPreferences or disk in clear text
[ ] Biometric protection preserved if it existed before migration (the FragmentActivity + LocalAuthenticationOptions constructor)
```

**Verification:**

```bash
# Flag any plain SharedPreferences write that looks credential-related
grep -rniE "getSharedPreferences|SharedPreferences" --include="*.kt" --include="*.java" . \
  | grep -iE "token|credential|auth|access"
```

> Migrating §7.7 changes how `SecureCredentialsManager` is *constructed* (build an `AuthenticationAPIClient` first), but it must still be a `SecureCredentialsManager`. Never downgrade to a plain `CredentialsManager` + `SharedPreferencesStorage` for token storage as a shortcut to make the build pass.

### 3. PKCE Flow Preserved

```text
[ ] Web Auth still goes through WebAuthProvider (PKCE is automatic — just verify WebAuthProvider.login is used)
[ ] No manual token exchange without a code verifier
[ ] No implicit grant flow introduced
```

### 4. Session Cleanup on Logout

```text
[ ] Logout clears the Auth0 session (WebAuthProvider.logout)
[ ] Logout clears stored credentials (clearCredentials() — note §8.3: in v4 this clears ALL storage)
[ ] No orphaned tokens after logout
```

> §8.3: `clearCredentials()` now clears **all** storage including API credentials. This is *more* thorough, not less — it does not weaken logout cleanup. If the app intentionally kept some data in the same `Storage` across logout, flag it; do not work around it by skipping `clearCredentials()`.

---

## Migration-Specific Security Checks

### When Storage / Credentials APIs Change (§7.7, §8.1, §8.3, §8.4)

- Verify credentials stored under v3 are still readable after the SDK update (storage format is backward compatible). If not, the app should prompt re-login rather than crash.
- Verify biometric protection is preserved: the biometric `SecureCredentialsManager` constructor (with `FragmentActivity` + `LocalAuthenticationOptions`) must remain in use if it was before.
- §8.1 (`minTtl` default 60s) and §8.3 (`clearCredentials()` clears all) are behavioral — confirm they don't break a security assumption the app relied on.

### When Auth Flow APIs Change (§7.4 DPoP, scopes)

- Verify the same scopes are still requested — especially `offline_access` for refresh tokens.
- Verify the same audience is still passed for API access tokens.
- Verify the callback URL scheme still matches the Auth0 Dashboard configuration.
- §7.4: moving `useDPoP(context)` to the login builder must not silently drop DPoP — if the app used DPoP before, it must still configure it (now per-request).

### When the Management API Is Removed (§7.2)

- Confirm no Management API token is, or ever was, shipped in the app. If one was, treat it as a leaked credential: it must be rotated and removed, and the operation moved to a backend.

### When Error Handling Changes (§7.5)

- Removing the `DPoPException.UNSUPPORTED_ERROR` branch must not remove handling for *other* error cases.
- Never expose raw error details containing tokens or secrets to the user or to logs.

---

## Post-Migration Security Verification

Run after the build succeeds:

```bash
# 1. No secrets in committed code
grep -rniE "client_secret|secret_key|private_key" \
  --include="*.kt" --include="*.java" --include="*.xml" --include="*.gradle" --include="*.kts" . \
  | grep -viE "//|/\*|TODO|removed"

# 2. No plain-text token storage
grep -rniE "getSharedPreferences|openFileOutput" --include="*.kt" --include="*.java" . \
  | grep -iE "token|credential|access"

# 3. No tokens logged
grep -rniE "Log\.[dveiw]\(|println\(|System\.out" --include="*.kt" --include="*.java" . \
  | grep -iE "token|credential|accessToken|idToken|refreshToken" | grep -viE "//"

# 4. strings.xml holds only safe values (domain + clientId/scheme)
grep -rniE "com_auth0_(domain|client_id|scheme)" --include="strings.xml" .
```

---

## If Security Is Compromised

If during migration you discover the project ALREADY has a security issue (pre-existing, not caused by migration — e.g. a Management API token in source, tokens in plain SharedPreferences, a hardcoded client secret):

1. **Inform the user immediately** — do not silently fix it or ignore it.
2. State what the issue is and why it's a risk.
3. Offer to fix it as part of the migration or as a separate step.
4. Never commit code that introduces a NEW security issue, even if the old code already had one.
