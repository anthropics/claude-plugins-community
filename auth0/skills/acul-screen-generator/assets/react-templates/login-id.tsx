// ACUL React — login-id screen boilerplate
// SDK: @auth0/auth0-acul-react
// Customize: apply design tokens, adjust layout, add/remove social providers

import React, { useState } from 'react'
import {
  useScreen,
  useTransaction,
  useErrors,
  useLoginIdentifiers,
  login,
  federatedLogin,
  passkeyLogin,
} from '@auth0/auth0-acul-react/login-id'
// Import your theme: CSS Modules, Tailwind classes, or styled-components

interface LoginIdScreenProps {}

export const LoginIdScreen: React.FC<LoginIdScreenProps> = () => {
  // SDK hooks
  const screen = useScreen()
  const { alternateConnections } = useTransaction()
  const { hasErrors, errors } = useErrors()
  const identifiers = useLoginIdentifiers()

  // Local state
  const [username, setUsername] = useState('')
  const [captcha, setCaptcha] = useState('')
  const [loading, setLoading] = useState(false)

  // Handlers
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    await login({ username, captcha: captcha || undefined })
    setLoading(false)
  }

  const handleSocial = async (connectionName: string) => {
    await federatedLogin({ connection: connectionName })
  }

  // Dynamic label from configured identifiers
  const identifierLabel = identifiers?.length
    ? `Enter your ${identifiers.join(' or ')}`
    : 'Email or username'

  return (
    <div className="acul-page-wrapper">
      <div className="acul-card">
        {/* Logo slot */}
        <div className="acul-logo-slot" />

        {/* Heading */}
        <h1 className="acul-heading">
          {screen.texts?.title ?? 'Log in'}
        </h1>
        {screen.texts?.description && (
          <p className="acul-subheading">{screen.texts.description}</p>
        )}

        {/* Error banner */}
        {hasErrors && (
          <div className="acul-error-banner" role="alert">
            {errors.map((err, i) => (
              <p key={i}>{err.message}</p>
            ))}
          </div>
        )}

        {/* Login form */}
        <form onSubmit={handleSubmit} noValidate>
          <div className="acul-field">
            <label className="acul-label" htmlFor="username">
              {screen.texts?.usernameLabel ?? identifierLabel}
            </label>
            <input
              id="username"
              className="acul-input"
              type="text"
              name="username"
              autoComplete="username"
              value={username}
              onChange={e => setUsername(e.target.value)}
              required
            />
          </div>

          {/* Captcha (only if configured) */}
          {screen.isCaptchaAvailable && (
            <div className="acul-field">
              <label className="acul-label" htmlFor="captcha">
                {screen.texts?.captchaLabel ?? 'Security code'}
              </label>
              <input
                id="captcha"
                className="acul-input"
                type="text"
                value={captcha}
                onChange={e => setCaptcha(e.target.value)}
              />
            </div>
          )}

          <button
            type="submit"
            className="acul-btn-primary"
            disabled={loading || !username}
          >
            {loading ? 'Loading...' : (screen.texts?.buttonText ?? 'Continue')}
          </button>
        </form>

        {/* Passkey (only if enabled) */}
        {screen.isPasskeyEnabled && (
          <button
            className="acul-btn-secondary"
            onClick={() => passkeyLogin()}
          >
            {screen.texts?.passkeyButtonText ?? 'Use a passkey'}
          </button>
        )}

        {/* Social login */}
        {alternateConnections && alternateConnections.length > 0 && (
          <>
            <div className="acul-divider">
              <span>{screen.texts?.separatorText ?? 'Or'}</span>
            </div>
            <div className="acul-social-buttons">
              {alternateConnections.map(conn => (
                <button
                  key={conn.name}
                  className="acul-social-btn"
                  onClick={() => handleSocial(conn.name)}
                  aria-label={`Continue with ${conn.displayName}`}
                >
                  {conn.iconUrl && (
                    <img src={conn.iconUrl} alt="" width={20} height={20} />
                  )}
                  <span>Continue with {conn.displayName}</span>
                </button>
              ))}
            </div>
          </>
        )}

        {/* Footer links */}
        <div className="acul-footer-links">
          <a href={screen.links?.signUp ?? '#'}>
            {screen.texts?.signupActionLinkText ?? "Don't have an account? Sign up"}
          </a>
        </div>
      </div>
    </div>
  )
}
