// ACUL JS — login-password screen boilerplate
// SDK: @auth0/auth0-acul-js
// Customize: apply design tokens, adjust layout

import LoginPassword from '@auth0/auth0-acul-js/login-password'

const manager = new LoginPassword()

function renderErrors() {
  if (!manager.transaction.hasErrors) return ''
  const msgs = manager.getErrors().map(e => `<p>${e.message}</p>`).join('')
  return `<div class="acul-error-banner" role="alert">${msgs}</div>`
}

function renderSocialButtons() {
  const connections = manager.transaction.alternateConnections ?? []
  if (!connections.length) return ''

  return `
    <div class="acul-divider">
      <span>${manager.screen.texts?.separatorText ?? 'Or'}</span>
    </div>
    ${connections.map(conn => `
      <button class="acul-social-btn" data-connection="${conn.name}">
        ${conn.iconUrl ? `<img src="${conn.iconUrl}" alt="" width="20" height="20" />` : ''}
        <span>Continue with ${conn.displayName}</span>
      </button>
    `).join('')}
  `
}

function render() {
  const container = document.getElementById('app')
  container.innerHTML = `
    <div class="acul-page-wrapper">
      <div class="acul-card">
        <div class="acul-logo-slot"></div>

        <h1 class="acul-heading">
          ${manager.screen.texts?.title ?? 'Enter your password'}
        </h1>

        ${renderErrors()}

        <form id="login-password-form" novalidate>
          <div class="acul-field">
            <label class="acul-label" for="password">
              ${manager.screen.texts?.passwordLabel ?? 'Password'}
            </label>
            <div class="acul-input-wrapper">
              <input
                id="password"
                class="acul-input"
                type="password"
                name="password"
                autocomplete="current-password"
                required
              />
              <button type="button" id="toggle-password" class="acul-input-toggle">
                Show
              </button>
            </div>
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
            ${manager.screen.texts?.buttonText ?? 'Log in'}
          </button>
        </form>

        ${manager.screen.isPasskeyEnabled ? `
          <button id="passkey-btn" class="acul-btn-secondary">
            ${manager.screen.texts?.passkeyButtonText ?? 'Use a passkey instead'}
          </button>
        ` : ''}

        ${renderSocialButtons()}

        <div class="acul-footer-links">
          <a href="#">
            ${manager.screen.texts?.forgotPasswordText ?? 'Forgot password?'}
          </a>
        </div>
      </div>
    </div>
  `

  attachEventListeners()
}

function attachEventListeners() {
  document.getElementById('login-password-form')?.addEventListener('submit', async (e) => {
    e.preventDefault()
    const submitBtn = document.getElementById('submit-btn')
    submitBtn.disabled = true
    submitBtn.textContent = 'Loading...'

    const password = document.getElementById('password').value
    const captcha = document.getElementById('captcha')?.value

    await manager.login({ password, captcha: captcha || undefined })

    submitBtn.disabled = false
    submitBtn.textContent = manager.screen.texts?.buttonText ?? 'Log in'
  })

  document.getElementById('toggle-password')?.addEventListener('click', () => {
    const input = document.getElementById('password')
    const btn = document.getElementById('toggle-password')
    if (input.type === 'password') {
      input.type = 'text'
      btn.textContent = 'Hide'
    } else {
      input.type = 'password'
      btn.textContent = 'Show'
    }
  })

  document.getElementById('passkey-btn')?.addEventListener('click', async () => {
    await manager.passkeyLogin()
  })

  document.querySelectorAll('.acul-social-btn').forEach(btn => {
    btn.addEventListener('click', async () => {
      await manager.federatedLogin({ connection: btn.dataset.connection })
    })
  })
}

render()
