# Auth0 ACUL React SDK Reference

Package: `@auth0/auth0-acul-react`

Each screen has its own import path. Import hooks and action functions from the screen-specific path.

---

## Import Pattern

```tsx
import {
  useScreen,
  useTransaction,
  useErrors,
  useLoginIdentifiers,
  login,
  federatedLogin,
  passkeyLogin,
} from '@auth0/auth0-acul-react/login-id'
```

Replace `login-id` with the screen name (e.g., `signup`, `login-password`, `mfa-otp-challenge`).

---

## Common Hooks

### `useScreen()`
Returns screen configuration and localised text strings.
```tsx
const screen = useScreen()
screen.texts?.title          // screen heading text
screen.texts?.description    // subheading/description
screen.name                  // current screen name
screen.links?.signUp         // navigation link to signup
screen.links?.resetPassword  // navigation link to password reset
screen.links?.login          // navigation link to login
```

### `useTransaction()`
Returns transaction state and available connections.
```tsx
const { hasErrors, alternateConnections, connection } = useTransaction()
alternateConnections   // array of social/enterprise connections
connection.name        // primary connection name
```

### `useErrors()`
Returns error state from the current transaction.
```tsx
const { hasErrors, errors } = useErrors()
// errors: array of { code, message }
```

### `useLoginIdentifiers()`
Returns active identifier types for dynamic label generation.
```tsx
const identifiers = useLoginIdentifiers()
// ['email', 'username'] → "Enter your email or username"
```

---

## Action Functions

Action functions are imported alongside hooks and called from event handlers.

### Authentication actions
```tsx
login({ username, password, captcha })         // login-id, login-password
federatedLogin({ connection: 'google-oauth2' }) // social login
passkeyLogin()                                  // passkey prompt (native dialog)
pickCountryCode()                               // phone country code picker
```

### Signup actions
```tsx
signup({ email, password, username })
```

### MFA actions
```tsx
continueWithMfaOtp({ code })
continueWithMfaSms({ code })
continueWithEmail({ code })
enrollWithTotp({ code })
```

### Password reset actions
```tsx
requestPasswordReset({ email })
resetPassword({ password, confirmPassword })
```

### Session actions
```tsx
logout()
```

---

## Standard Component Structure

```tsx
import React, { useState } from 'react'
import {
  useScreen, useTransaction, useErrors,
  login, federatedLogin, passkeyLogin,
} from '@auth0/auth0-acul-react/login-id'

export const LoginIdScreen: React.FC = () => {
  // 1. SDK hooks
  const screen = useScreen()
  const { alternateConnections } = useTransaction()
  const { hasErrors, errors } = useErrors()

  // 2. Local state
  const [username, setUsername] = useState('')
  const [loading, setLoading] = useState(false)
  const [captcha, setCaptcha] = useState('')

  // 3. Event handlers
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    await login({ username, captcha })
    setLoading(false)
  }

  const handleSocial = async (connectionName: string) => {
    await federatedLogin({ connection: connectionName })
  }

  // 4. JSX
  return (
    <div className="page-wrapper">
      <div className="card">
        {/* Logo slot */}
        <div className="logo-slot" />

        {/* Title from screen config */}
        <h1>{screen.texts?.title ?? 'Log in'}</h1>

        {/* Error banner */}
        {hasErrors && (
          <div className="error-banner">
            {errors.map(e => <p key={e.code}>{e.message}</p>)}
          </div>
        )}

        {/* Form */}
        <form onSubmit={handleSubmit}>
          <label htmlFor="username">
            {screen.texts?.usernameLabel ?? 'Email or username'}
          </label>
          <input
            id="username"
            type="text"
            value={username}
            onChange={e => setUsername(e.target.value)}
          />
          <button type="submit" disabled={loading}>
            {loading ? 'Logging in...' : (screen.texts?.buttonText ?? 'Continue')}
          </button>
        </form>

        {/* Social login */}
        {alternateConnections?.length > 0 && (
          <>
            <div className="divider"><span>Or</span></div>
            {alternateConnections.map(conn => (
              <button
                key={conn.name}
                onClick={() => handleSocial(conn.name)}
                className="social-btn"
              >
                Continue with {conn.displayName}
              </button>
            ))}
          </>
        )}

        {/* Footer links */}
        <div className="footer-links">
          <a href="#">Sign up</a>
          <a href="#">Forgot password?</a>
        </div>
      </div>
    </div>
  )
}
```

---

## Conditional Features

```tsx
// Captcha (check if configured)
{screen.isCaptchaAvailable && (
  <input value={captcha} onChange={e => setCaptcha(e.target.value)} />
)}

// Passkey button
{screen.isPasskeyEnabled && (
  <button onClick={() => passkeyLogin()}>Use passkey</button>
)}

// Country code for phone flows
{screen.isPhoneFlow && (
  <button onClick={() => pickCountryCode()}>+1</button>
)}
```

---

## Screen-Specific Imports Quick Reference

| Screen | Import path |
|--------|-------------|
| login-id | `@auth0/auth0-acul-react/login-id` |
| login-password | `@auth0/auth0-acul-react/login-password` |
| signup | `@auth0/auth0-acul-react/signup` |
| signup-id | `@auth0/auth0-acul-react/signup-id` |
| signup-password | `@auth0/auth0-acul-react/signup-password` |
| mfa-otp-challenge | `@auth0/auth0-acul-react/mfa-otp-challenge` |
| mfa-email-challenge | `@auth0/auth0-acul-react/mfa-email-challenge` |
| mfa-sms-challenge | `@auth0/auth0-acul-react/mfa-sms-challenge` |
| reset-password-request | `@auth0/auth0-acul-react/reset-password-request` |
| reset-password | `@auth0/auth0-acul-react/reset-password` |
| passkey-enrollment | `@auth0/auth0-acul-react/passkey-enrollment` |

For full screen list and fallback URLs → see `screen-catalog.md`.
