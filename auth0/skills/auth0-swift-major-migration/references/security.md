# Security Checklist — Auth0.swift Migration

Security invariants that MUST be preserved during any major version migration. Verify each item after migration is complete.

---

## Non-Negotiable Invariants

These must hold true before and after migration. If any are violated, the migration has a security bug.

### 1. No Secrets in Source Code

```plaintext
[ ] No client_secret in any Swift file (native apps use PKCE, not secrets)
[ ] No hardcoded tokens or API keys
[ ] No credentials in Info.plist (only domain and clientId belong in Auth0.plist)
[ ] No tokens logged to console in production builds
```

**Verification:**
```bash
grep -ri "client_secret\|api_key\|apikey\|secret_key" --include="*.swift" --include="*.plist" .
```

### 2. Secure Token Storage

```plaintext
[ ] Credentials stored in Keychain via CredentialsManager (not UserDefaults, not files)
[ ] No tokens stored in plain text anywhere
[ ] Biometric protection preserved if it existed before migration
```

**Verification:**
```bash
grep -r "UserDefaults.*token\|UserDefaults.*credential\|UserDefaults.*auth" --include="*.swift" .
```

### 3. PKCE Flow Preserved

```plaintext
[ ] WebAuth still uses PKCE (this is automatic in Auth0.swift — just verify webAuth() is used)
[ ] No manual token exchange without code_verifier
[ ] No implicit grant flow introduced
```

### 4. Session Cleanup on Logout

```plaintext
[ ] Logout clears the Auth0 session (calls webAuth().logout(); changed from webAuth().clearSession() in v2)
[ ] Logout clears stored credentials from Keychain
[ ] No orphaned tokens after logout
```

---

## Migration-Specific Security Checks

### When Storage APIs Change

If the new version changes how credentials are stored (method signatures, storage format):

- Verify that existing stored credentials are still accessible after the SDK update (backward-compatible storage)
- If storage format changed, the SDK should handle migration transparently
- If not, the user may need to prompt re-login after update

### When Auth Flow APIs Change

If login/logout method signatures change:

- Verify the same scopes are still requested (especially `offline_access` for refresh tokens)
- Verify the same audience is still passed (for API access tokens)
- Verify redirect URIs still match what's configured in Auth0 Dashboard

### When Error Handling Changes

If error types are renamed or restructured:

- Verify that `userCancelled` (or equivalent) is still caught and handled gracefully
- Verify that authentication failures still surface meaningful messages
- Never expose raw error details containing tokens or secrets to the user

### When Protocol Conformances Change

If WebAuth/CredentialsManager/etc. protocols gain Sendable or other marker requirements:

- Verify custom implementations still compile
- For `@unchecked Sendable` additions, verify thread safety is actually maintained
- Never add `@unchecked Sendable` to a class with unprotected mutable state

---

## Post-Migration Security Verification

Run these checks after the build succeeds:

```bash
# 1. No secrets in committed code
grep -ri "secret\|password\|private_key" --include="*.swift" . | grep -v "//\|/\*\|client_secret.*removed\|TODO"

# 2. No plain-text token storage
grep -ri "UserDefaults.*set.*token\|fileManager.*write.*token" --include="*.swift" .

# 3. Auth0.plist contains only safe values (domain + clientId)
find . -name "Auth0.plist" -exec cat {} \; 2>/dev/null

# 4. No credentials in build logs (check for print statements with tokens)
grep -ri "print.*token\|print.*credential\|NSLog.*token" --include="*.swift" . | grep -v "//\|/\*"
```

---

## If Security is Compromised

If during migration you discover that the project ALREADY has a security issue (pre-existing, not caused by migration):

1. **Inform the user immediately** — do not silently fix it or ignore it
2. Note what the issue is and why it's a risk
3. Offer to fix it as part of the migration or as a separate step
4. Never commit code that introduces NEW security issues, even if the old code had them
