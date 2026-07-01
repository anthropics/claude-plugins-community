// ACUL React — login-password screen boilerplate
// SDK: @auth0/auth0-acul-react
// Customize: apply design tokens, adjust layout, add/remove social providers

import React, { useState } from 'react'
import {
  useScreen,
  useTransaction,
  useErrors,
  login,
  federatedLogin,
  passkeyLogin,
} from '@auth0/auth0-acul-react/login-password'

interface LoginPasswordScreenProps {}

export const LoginPasswordScreen: React.FC<LoginPasswordScreenProps> = () => {
  const screen = useScreen()
  const { alternateConnections } = useTransaction()
  const { hasErrors, errors } = useErrors()

  const [password, setPassword] = useState('')
  const [captcha, setCaptcha] = useState('')
  const [loading, setLoading] = useState(false)
  const [showPassword, setShowPassword] = useState(false)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    await login({ password, captcha: captcha || undefined })
    setLoading(false)
  }

  return (
    <div className="acul-page-wrapper">
      <div className="acul-card">
        <div className="acul-logo-slot" />

        <h1 className="acul-heading">
          {screen.texts?.title ?? 'Enter your password'}
        </h1>

        {hasErrors && (
          <div className="acul-error-banner" role="alert">
            {errors.map((err, i) => <p key={i}>{err.message}</p>)}
          </div>
        )}

        <form onSubmit={handleSubmit} noValidate>
          <div className="acul-field">
            <label className="acul-label" htmlFor="password">
              {screen.texts?.passwordLabel ?? 'Password'}
            </label>
            <div className="acul-input-wrapper">
              <input
                id="password"
                className="acul-input"
                type={showPassword ? 'text' : 'password'}
                name="password"
                autoComplete="current-password"
                value={password}
                onChange={e => setPassword(e.target.value)}
                required
              />
              <button
                type="button"
                className="acul-input-toggle"
                onClick={() => setShowPassword(v => !v)}
                aria-label={showPassword ? 'Hide password' : 'Show password'}
              >
                {showPassword ? 'Hide' : 'Show'}
              </button>
            </div>
          </div>

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
            disabled={loading || !password}
          >
            {loading ? 'Loading...' : (screen.texts?.buttonText ?? 'Log in')}
          </button>
        </form>

        {screen.isPasskeyEnabled && (
          <button className="acul-btn-secondary" onClick={() => passkeyLogin()}>
            {screen.texts?.passkeyButtonText ?? 'Use a passkey instead'}
          </button>
        )}

        {alternateConnections && alternateConnections.length > 0 && (
          <>
            <div className="acul-divider">
              <span>{screen.texts?.separatorText ?? 'Or'}</span>
            </div>
            {alternateConnections.map(conn => (
              <button
                key={conn.name}
                className="acul-social-btn"
                onClick={() => federatedLogin({ connection: conn.name })}
              >
                {conn.iconUrl && <img src={conn.iconUrl} alt="" width={20} height={20} />}
                <span>Continue with {conn.displayName}</span>
              </button>
            ))}
          </>
        )}

        <div className="acul-footer-links">
          <a href={screen.links?.resetPassword ?? '#'}>
            {screen.texts?.forgotPasswordText ?? 'Forgot password?'}
          </a>
        </div>
      </div>
    </div>
  )
}
