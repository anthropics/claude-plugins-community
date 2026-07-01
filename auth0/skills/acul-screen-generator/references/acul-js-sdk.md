# Auth0 ACUL JS SDK Reference

Package: `@auth0/auth0-acul-js`

Uses a manager class pattern. Each screen exports a default class with methods matching available actions.

---

## Import Pattern

```typescript
import LoginId from '@auth0/auth0-acul-js/login-id'

const manager = new LoginId()
```

Replace `login-id` with the screen name. Class name is PascalCase of the screen name.

---

## Manager Instance Properties

```typescript
manager.transaction.hasErrors          // boolean
manager.transaction.alternateConnections  // social/enterprise connections array
manager.transaction.connection         // primary connection
manager.getErrors()                    // returns array of { code, message }
manager.screen.texts                   // localised text strings
manager.screen.name                    // current screen name
manager.screen.isCaptchaAvailable      // boolean
manager.screen.isPasskeyEnabled        // boolean
```

---

## Common Methods by Screen

### Login screens
```typescript
// login-id
const manager = new LoginId()
await manager.login({ username: 'user@example.com', captcha: '...' })
await manager.federatedLogin({ connection: 'google-oauth2' })
await manager.passkeyLogin()
await manager.pickCountryCode()

// login-password
const manager = new LoginPassword()
await manager.login({ password: 'secret', captcha: '...' })
await manager.federatedLogin({ connection: 'google-oauth2' })
await manager.passkeyLogin()
```

### Signup screens
```typescript
const manager = new Signup()
await manager.signup({ email: 'user@example.com', password: 'secret' })
await manager.federatedLogin({ connection: 'google-oauth2' })
```

### MFA screens
```typescript
// mfa-otp-challenge
const manager = new MfaOtpChallenge()
await manager.continueWithMfaOtp({ code: '123456' })

// mfa-sms-challenge
const manager = new MfaSmsChallenge()
await manager.continueWithMfaSms({ code: '123456' })

// mfa-email-challenge
const manager = new MfaEmailChallenge()
await manager.continueWithEmail({ code: '123456' })
```

### Password reset screens
```typescript
const manager = new ResetPasswordRequest()
await manager.requestPasswordReset({ email: 'user@example.com' })

const manager = new ResetPassword()
await manager.resetPassword({ password: 'newpass', confirmPassword: 'newpass' })
```

---

## Standard Component Structure (Vanilla JS)

```javascript
import LoginId from '@auth0/auth0-acul-js/login-id'

const manager = new LoginId()

function render() {
  const container = document.getElementById('app')
  container.innerHTML = `
    <div class="page-wrapper">
      <div class="card">
        <div class="logo-slot"></div>
        <h1>${manager.screen.texts?.title ?? 'Log in'}</h1>

        ${manager.transaction.hasErrors ? `
          <div class="error-banner">
            ${manager.getErrors().map(e => `<p>${e.message}</p>`).join('')}
          </div>
        ` : ''}

        <form id="login-form">
          <label for="username">
            ${manager.screen.texts?.usernameLabel ?? 'Email or username'}
          </label>
          <input id="username" type="text" name="username" />

          ${manager.screen.isCaptchaAvailable ? `
            <input id="captcha" type="text" placeholder="Enter captcha" />
          ` : ''}

          <button type="submit">
            ${manager.screen.texts?.buttonText ?? 'Continue'}
          </button>
        </form>

        ${manager.transaction.alternateConnections?.length ? `
          <div class="divider"><span>Or</span></div>
          ${manager.transaction.alternateConnections.map(conn => `
            <button class="social-btn" data-connection="${conn.name}">
              Continue with ${conn.displayName}
            </button>
          `).join('')}
        ` : ''}

        <div class="footer-links">
          <a href="#">Sign up</a>
          <a href="#">Forgot password?</a>
        </div>
      </div>
    </div>
  `

  // Attach event listeners after render
  document.getElementById('login-form').addEventListener('submit', async (e) => {
    e.preventDefault()
    const username = document.getElementById('username').value
    const captcha = document.getElementById('captcha')?.value
    await manager.login({ username, captcha })
  })

  document.querySelectorAll('.social-btn').forEach(btn => {
    btn.addEventListener('click', async () => {
      const connection = btn.dataset.connection
      await manager.federatedLogin({ connection })
    })
  })

  if (manager.screen.isPasskeyEnabled) {
    // Passkey button handler
    document.getElementById('passkey-btn')?.addEventListener('click', async () => {
      await manager.passkeyLogin()
    })
  }
}

render()
```

---

## Manager Class Name Reference

| Screen | Import path | Class name |
|--------|-------------|------------|
| login-id | `@auth0/auth0-acul-js/login-id` | `LoginId` |
| login-password | `@auth0/auth0-acul-js/login-password` | `LoginPassword` |
| signup | `@auth0/auth0-acul-js/signup` | `Signup` |
| signup-id | `@auth0/auth0-acul-js/signup-id` | `SignupId` |
| signup-password | `@auth0/auth0-acul-js/signup-password` | `SignupPassword` |
| mfa-otp-challenge | `@auth0/auth0-acul-js/mfa-otp-challenge` | `MfaOtpChallenge` |
| mfa-email-challenge | `@auth0/auth0-acul-js/mfa-email-challenge` | `MfaEmailChallenge` |
| mfa-sms-challenge | `@auth0/auth0-acul-js/mfa-sms-challenge` | `MfaSmsChallenge` |
| reset-password-request | `@auth0/auth0-acul-js/reset-password-request` | `ResetPasswordRequest` |
| reset-password | `@auth0/auth0-acul-js/reset-password` | `ResetPassword` |
| passkey-enrollment | `@auth0/auth0-acul-js/passkey-enrollment` | `PasskeyEnrollment` |

For full screen list and fallback URLs → see `screen-catalog.md`.
