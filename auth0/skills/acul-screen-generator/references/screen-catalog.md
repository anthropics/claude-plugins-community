# ACUL Screen Catalog

Complete reference for all 68 React + 71 JS ACUL screens with their reference sources, SDK callbacks, and URLs.

**Reference priority per screen:**
1. **auth0-acul-samples** if `Samples` column = ✅ → fetch full modular implementation
2. **SDK examples** if `Samples` column = ❌ → fetch the markdown example for SDK usage
3. **assets/templates** — structural pattern only, never for hooks/actions

The `Samples` column marks which screens have a complete implementation in `auth0-acul-samples`.

> **Note:** `continueMethod()` in the tables below is a placeholder — the actual method name is screen-specific (e.g., `continueWithMfaOtp()`, `continueWithMfaSms()`). Always fetch the SDK example to get the exact method name and payload shape.

## Table of Contents
1. [URL Patterns](#url-patterns)
2. [Hook Patterns](#hook-patterns)
3. [Login & Authentication](#login--authentication)
4. [Signup & Registration](#signup--registration)
5. [Password Reset](#password-reset)
6. [Password Reset + MFA Challenges](#password-reset--mfa-challenges)
7. [MFA — Enrollment & Options](#mfa--enrollment--options)
8. [MFA — Email](#mfa--email)
9. [MFA — SMS / Voice / Phone](#mfa--sms--voice--phone)
10. [MFA — OTP (TOTP)](#mfa--otp-totp)
11. [MFA — Push Notifications](#mfa--push-notifications)
12. [MFA — WebAuthn](#mfa--webauthn)
13. [MFA — Recovery Codes](#mfa--recovery-codes)
14. [Passkeys](#passkeys)
15. [Identifier Challenges](#identifier-challenges)
16. [Device Authorization](#device-authorization)
17. [Organization Management](#organization-management)
18. [Consent & Security](#consent--security)
19. [Session / Logout](#session--logout)
20. [Email Verification](#email-verification)
21. [JS-Only Screens](#js-only-screens)

---

## URL Patterns

### auth0-acul-samples (Priority 1)
```
React:
  directory: https://github.com/auth0-samples/auth0-acul-samples/tree/main/react/src/screens/<screen-name>
  index.tsx:  https://github.com/auth0-samples/auth0-acul-samples/blob/main/react/src/screens/<screen-name>/index.tsx
  manager:    https://github.com/auth0-samples/auth0-acul-samples/blob/main/react/src/screens/<screen-name>/hooks/use<ScreenName>Manager.ts

React-JS:
  directory: https://github.com/auth0-samples/auth0-acul-samples/tree/main/react-js/src/screens/<screen-name>
  index.tsx:  https://github.com/auth0-samples/auth0-acul-samples/blob/main/react-js/src/screens/<screen-name>/index.tsx
```

### SDK examples (Priority 2)
```
React: https://github.com/auth0/universal-login/blob/master/packages/auth0-acul-react/examples/<screen-name>.md
JS:    https://github.com/auth0/universal-login/blob/master/packages/auth0-acul-js/examples/<screen-name>.md
```

---

## Hook Patterns

ACUL screens use two patterns. The reference fetch tells you which applies.

**Pattern A — Generic hooks** (most login/signup screens):
```tsx
import { useScreen, useTransaction, useErrors, login } from '@auth0/auth0-acul-react/<screen>'
const screen = useScreen()
const { alternateConnections } = useTransaction()
```

**Pattern B — Screen-specific hook** (most MFA, reset-password-mfa, recovery screens):
```tsx
import { useScreenName, continueMethod } from '@auth0/auth0-acul-react/<screen>'
const screen = useScreenName()   // e.g., useMfaRecoveryCodeEnrollment()
await continueMethod({ ...payload })
```

**JS — Manager class** (both patterns map to this):
```js
import ScreenClass from '@auth0/auth0-acul-js/<screen>'
const manager = new ScreenClass()
await manager.continueMethod({ ...payload })
```

---

## Login & Authentication

| Screen | Samples (React) | Samples (React-JS) | SDK React | SDK JS | Primary Action | Notes |
|--------|-----------------|--------------------|-----------|--------|----------------|-------|
| `login` | ✅ | ✅ | ✅ | ✅ | `login()`, `federatedLogin()` | All-identifier login |
| `login-id` | ✅ | ✅ | ✅ | ✅ | `login()`, `federatedLogin()`, `passkeyLogin()` | Identifier-first step |
| `login-password` | ✅ | ✅ | ✅ | ✅ | `login()`, `federatedLogin()`, `passkeyLogin()` | Password entry step |
| `login-passwordless-email-code` | ✅ | ❌ | ✅ | ✅ | `continueMethod()` | Email OTP |
| `login-passwordless-sms-otp` | ✅ | ❌ | ✅ | ✅ | `continueMethod()` | SMS OTP |
| `login-email-verification` | ❌ | ❌ | ✅ | ✅ | — | Gate screen, no action |

---

## Signup & Registration

| Screen | Samples (React) | Samples (React-JS) | SDK React | SDK JS | Primary Action | Notes |
|--------|-----------------|--------------------|-----------|--------|----------------|-------|
| `signup` | ✅ | ❌ | ✅ | ✅ | `signup()`, `federatedLogin()` | Combined signup |
| `signup-id` | ✅ | ❌ | ✅ | ✅ | `signup()`, `federatedLogin()` | Identifier-first |
| `signup-password` | ✅ | ❌ | ✅ | ✅ | `signup()` | Password entry |
| `accept-invitation` | ❌ | ❌ | ✅ | ✅ | `signup()` | Org invite |
| `redeem-ticket` | ❌ | ❌ | ✅ | ✅ | — | Ticket-based access |

---

## Password Reset

| Screen | Samples (React) | Samples (React-JS) | SDK React | SDK JS | Primary Action | Notes |
|--------|-----------------|--------------------|-----------|--------|----------------|-------|
| `reset-password-request` | ✅ | ❌ | ✅ | ✅ | `requestPasswordReset()` | Sends reset email |
| `reset-password-email` | ✅ | ❌ | ✅ | ✅ | — | Email sent confirmation |
| `reset-password` | ✅ | ❌ | ✅ | ✅ | `continueMethod()` | Enter new password |
| `reset-password-success` | ✅ | ❌ | ✅ | ✅ | — | Success state |
| `reset-password-error` | ✅ | ❌ | ✅ | ✅ | — | Error state |

---

## Password Reset + MFA Challenges

All screens: Pattern B (screen-specific hook + `continueMethod()`). Not in samples — use SDK examples.

| Screen | Samples (React) | SDK React | SDK JS | Primary Action |
|--------|-----------------|-----------|--------|----------------|
| `reset-password-mfa-email-challenge` | ❌ | ✅ | ✅ | `continueMethod()` |
| `reset-password-mfa-otp-challenge` | ❌ | ✅ | ✅ | `continueMethod()` |
| `reset-password-mfa-phone-challenge` | ❌ | ✅ | ✅ | `continueMethod()` |
| `reset-password-mfa-push-challenge-push` | ❌ | ✅ | ✅ | `continueMethod()` |
| `reset-password-mfa-recovery-code-challenge` | ❌ | ✅ | ✅ | `continueMethod()` |
| `reset-password-mfa-sms-challenge` | ❌ | ✅ | ✅ | `continueMethod()` |
| `reset-password-mfa-voice-challenge` | ❌ | ✅ | ✅ | `continueMethod()` |
| `reset-password-mfa-webauthn-platform-challenge` | ❌ | ✅ | ✅ | `continueMethod()` |
| `reset-password-mfa-webauthn-roaming-challenge` | ❌ | ✅ | ✅ | `continueMethod()` |

---

## MFA — Enrollment & Options

| Screen | Samples (React) | SDK React | SDK JS | Primary Action | Notes |
|--------|-----------------|-----------|--------|----------------|-------|
| `mfa-begin-enroll-options` | ✅ | ✅ | ✅ | — | Options list |
| `mfa-login-options` | ✅ | ✅ | ✅ | — | Login method picker |
| `mfa-detect-browser-capabilities` | ❌ | ✅ | ✅ | — | Capability check |
| `mfa-enroll-result` | ✅ | ✅ | ✅ | — | Enrollment confirmation |
| `mfa-country-codes` | ✅ | ✅ | ✅ | `continueMethod()` | Phone country picker |

---

## MFA — Email

| Screen | Samples (React) | SDK React | SDK JS | Primary Action |
|--------|-----------------|-----------|--------|----------------|
| `mfa-email-challenge` | ✅ | ✅ | ✅ | `continueMethod()` |
| `mfa-email-list` | ✅ | ✅ | ✅ | — |

---

## MFA — SMS / Voice / Phone

| Screen | Samples (React) | SDK React | SDK JS | Primary Action |
|--------|-----------------|-----------|--------|----------------|
| `mfa-sms-challenge` | ✅ | ✅ | ✅ | `continueMethod()` |
| `mfa-sms-enrollment` | ✅ | ✅ | ✅ | `continueMethod()` |
| `mfa-sms-list` | ✅ | ✅ | ✅ | — |
| `mfa-voice-challenge` | ❌ | ✅ | ✅ | `continueMethod()` |
| `mfa-voice-enrollment` | ❌ | ✅ | ✅ | `continueMethod()` |
| `mfa-phone-challenge` | ❌ | ✅ | ✅ | `continueMethod()` |
| `mfa-phone-enrollment` | ❌ | ✅ | ✅ | `continueMethod()` |

---

## MFA — OTP (TOTP)

Not in samples — use SDK examples.

| Screen | Samples (React) | SDK React | SDK JS | Primary Action |
|--------|-----------------|-----------|--------|----------------|
| `mfa-otp-challenge` | ❌ | ✅ | ✅ | `continueMethod()` |
| `mfa-otp-enrollment-qr` | ❌ | ✅ | ✅ | `continueMethod()` |
| `mfa-otp-enrollment-code` | ❌ | ✅ | ✅ | `continueMethod()` |

---

## MFA — Push Notifications

| Screen | Samples (React) | SDK React | SDK JS | Primary Action |
|--------|-----------------|-----------|--------|----------------|
| `mfa-push-welcome` | ✅ | ✅ | ✅ | — |
| `mfa-push-enrollment-qr` | ✅ | ✅ | ✅ | `continueMethod()` |
| `mfa-push-challenge-push` | ✅ | ✅ | ✅ | `continueMethod()` |
| `mfa-push-list` | ✅ | ✅ | ✅ | — |

---

## MFA — WebAuthn

Not in samples — use SDK examples.

| Screen | Samples (React) | SDK React | SDK JS | Primary Action | Notes |
|--------|-----------------|-----------|--------|----------------|-------|
| `mfa-webauthn-platform-enrollment` | ❌ | ✅ | ✅ | `submitPasskeyCredential()`, `snoozeEnrollment()`, `refuseEnrollmentOnThisDevice()` | 3 actions |
| `mfa-webauthn-platform-challenge` | ❌ | ✅ | ✅ | `continueMethod()` | |
| `mfa-webauthn-roaming-enrollment` | ❌ | ✅ | ✅ | `continueMethod()` | |
| `mfa-webauthn-roaming-challenge` | ❌ | ✅ | ✅ | `continueMethod()` | |
| `mfa-webauthn-change-key-nickname` | ❌ | ✅ | ✅ | `continueMethod()` | |
| `mfa-webauthn-enrollment-success` | ❌ | ✅ | ✅ | — | Success state |
| `mfa-webauthn-error` | ❌ | ✅ | ✅ | — | Error state |
| `mfa-webauthn-not-available-error` | ❌ | ✅ | ✅ | — | Capability error |

---

## MFA — Recovery Codes

Not in samples — use SDK examples.

| Screen | Samples (React) | SDK React | SDK JS | Primary Action | Notes |
|--------|-----------------|-----------|--------|----------------|-------|
| `mfa-recovery-code-enrollment` | ❌ | ✅ | ✅ | `continueMethod({ isCodeCopied })` | Screen-specific hook |
| `mfa-recovery-code-challenge` | ❌ | ✅ | ✅ | `continueMethod()` | |
| `mfa-recovery-code-challenge-new-code` | ❌ | ✅ | ✅ | `continueMethod()` | |

---

## Passkeys

| Screen | Samples (React) | SDK React | SDK JS | Primary Action | Notes |
|--------|-----------------|-----------|--------|----------------|-------|
| `passkey-enrollment` | ✅ | ✅ | ✅ | `submitPasskeyCredential()` | Native dialog |
| `passkey-enrollment-local` | ✅ | ✅ | ✅ | `continueMethod()` | Local device |

---

## Identifier Challenges

| Screen | Samples (React) | SDK React | SDK JS | Primary Action |
|--------|-----------------|-----------|--------|----------------|
| `email-identifier-challenge` | ✅ | ✅ | ✅ | `continueMethod()` |
| `phone-identifier-challenge` | ✅ | ✅ | ✅ | `continueMethod()` |
| `phone-identifier-enrollment` | ✅ | ✅ | ✅ | `continueMethod()` |
| `email-otp-challenge` | ❌ | ✅ | ✅ | `continueMethod()` |

---

## Device Authorization

Not in samples — use SDK examples.

| Screen | Samples (React) | SDK React | SDK JS | Primary Action |
|--------|-----------------|-----------|--------|----------------|
| `device-code-activation` | ❌ | ✅ | ✅ | `continueMethod()` |
| `device-code-confirmation` | ❌ | ✅ | ✅ | `continueMethod()` |
| `device-code-activation-allowed` | ❌ | ✅ | ✅ | — |
| `device-code-activation-denied` | ❌ | ✅ | ✅ | — |

---

## Organization Management

Not in samples — use SDK examples.

| Screen | Samples (React) | SDK React | SDK JS | Primary Action |
|--------|-----------------|-----------|--------|----------------|
| `organization-picker` | ❌ | ✅ | ✅ | `continueMethod()` |
| `organization-selection` | ❌ | ✅ | ✅ | `continueMethod()` |

---

## Consent & Security

Not in samples — use SDK examples.

| Screen | Samples (React) | SDK React | SDK JS | Primary Action |
|--------|-----------------|-----------|--------|----------------|
| `consent` | ❌ | ✅ | ✅ | `continueMethod()` |
| `customized-consent` | ❌ | ✅ | ✅ | `continueMethod()` |
| `interstitial-captcha` | ❌ | ✅ | ✅ | `continueMethod()` |

---

## Session / Logout

Not in samples — use SDK examples.

| Screen | Samples (React) | SDK React | SDK JS | Primary Action |
|--------|-----------------|-----------|--------|----------------|
| `logout` | ❌ | ✅ | ✅ | `logout()` |
| `logout-aborted` | ❌ | ✅ | ✅ | — |
| `logout-complete` | ❌ | ✅ | ✅ | — |

---

## Email Verification

| Screen | Samples (React) | SDK React | SDK JS | Primary Action |
|--------|-----------------|-----------|--------|----------------|
| `email-verification-result` | ❌ | ✅ | ✅ | — |

---

## JS-Only Screens

Only in `@auth0/auth0-acul-js`. No React SDK or samples equivalent. Use JS SDK examples.

| Screen | Primary Action | Notes |
|--------|----------------|-------|
| `brute-force-protection-unblock` | `unblockAccount()` | Account unblock |
| `brute-force-protection-unblock-success` | — | Success state |
| `brute-force-protection-unblock-failure` | — | Failure state |
| `get-current-screen-options` | — | Utility: read screen config |
| `get-current-theme-options` | — | Utility: read theme config |

JS SDK example URL:
```
https://github.com/auth0/universal-login/blob/master/packages/auth0-acul-js/examples/<screen-name>.md
```
