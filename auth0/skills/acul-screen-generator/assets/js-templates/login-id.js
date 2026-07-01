// ACUL JS — login-id screen boilerplate
// SDK: @auth0/auth0-acul-js
// Customize: apply design tokens, adjust layout, add/remove social providers

import LoginId from '@auth0/auth0-acul-js/login-id'

const manager = new LoginId()

function getIdentifierLabel() {
  // Dynamic label based on configured identifiers
  const ids = manager.screen.loginIdentifiers ?? []
  if (ids.length === 0) return 'Email or username'
  return `Enter your ${ids.join(' or ')}`
}

function renderSocialButtons() {
  const connections = manager.transaction.alternateConnections ?? []
  if (!connections.length) return ''

  const buttons = connections.map(conn => `
    <button
      class="acul-social-btn"
      data-connection="${conn.name}"
      aria-label="Continue with ${conn.displayName}"
    >
      ${conn.iconUrl ? `<img src="${conn.iconUrl}" alt="" width="20" height="20" />` : ''}
      <span>Continue with ${conn.displayName}</span>
    </button>
  `).join('')

  return `
    <div class="acul-divider">
      <span>${manager.screen.texts?.separatorText ?? 'Or'}</span>
    </div>
    <div class="acul-social-buttons">${buttons}</div>
  `
}

function renderErrors() {
  if (!manager.transaction.hasErrors) return ''
  const msgs = manager.getErrors().map(e => `<p>${e.message}</p>`).join('')
  return `<div class="acul-error-banner" role="alert">${msgs}</div>`
}

function render() {
  const container = document.getElementById('app')
  container.innerHTML = `
    <div class="acul-page-wrapper">
      <div class="acul-card">
        <div class="acul-logo-slot"></div>

        <h1 class="acul-heading">
          ${manager.screen.texts?.title ?? 'Log in'}
        </h1>

        ${renderErrors()}

        <form id="login-id-form" novalidate>
          <div class="acul-field">
            <label class="acul-label" for="username">
              ${manager.screen.texts?.usernameLabel ?? getIdentifierLabel()}
            </label>
            <input
              id="username"
              class="acul-input"
              type="text"
              name="username"
              autocomplete="username"
              required
            />
          </div>

          ${manager.screen.isCaptchaAvailable ? `
            <div class="acul-field">
              <label class="acul-label" for="captcha">
                ${manager.screen.texts?.captchaLabel ?? 'Security code'}
              </label>
              <input id="captcha" class="acul-input" type="text" />
            </div>
          ` : ''}

          <button id="submit-btn" type="submit" class="acul-btn-primary">
            ${manager.screen.texts?.buttonText ?? 'Continue'}
          </button>
        </form>

        ${manager.screen.isPasskeyEnabled ? `
          <button id="passkey-btn" class="acul-btn-secondary">
            ${manager.screen.texts?.passkeyButtonText ?? 'Use a passkey'}
          </button>
        ` : ''}

        ${renderSocialButtons()}

        <div class="acul-footer-links">
          <a href="#">
            ${manager.screen.texts?.signupActionLinkText ?? "Don't have an account? Sign up"}
          </a>
        </div>
      </div>
    </div>
  `

  attachEventListeners()
}

function attachEventListeners() {
  // Form submit
  document.getElementById('login-id-form')?.addEventListener('submit', async (e) => {
    e.preventDefault()
    const submitBtn = document.getElementById('submit-btn')
    submitBtn.disabled = true
    submitBtn.textContent = 'Loading...'

    const username = document.getElementById('username').value
    const captcha = document.getElementById('captcha')?.value

    await manager.login({ username, captcha: captcha || undefined })

    submitBtn.disabled = false
    submitBtn.textContent = manager.screen.texts?.buttonText ?? 'Continue'
  })

  // Passkey
  document.getElementById('passkey-btn')?.addEventListener('click', async () => {
    await manager.passkeyLogin()
  })

  // Social login
  document.querySelectorAll('.acul-social-btn').forEach(btn => {
    btn.addEventListener('click', async () => {
      await manager.federatedLogin({ connection: btn.dataset.connection })
    })
  })
}

render()
