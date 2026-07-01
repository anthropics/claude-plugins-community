# Social Login Provider Patterns

Patterns for rendering social login buttons in ACUL screens. Social connections come from `alternateConnections` on the transaction object — never hardcode connection names.

---

## Data Shape

```typescript
// From useTransaction() (React) or manager.transaction (JS)
alternateConnections: Array<{
  name: string          // e.g., "google-oauth2", "github", "apple"
  displayName: string   // e.g., "Google", "GitHub", "Apple"
  iconUrl?: string      // provider icon URL if available
  strategy: string      // e.g., "google-oauth2", "github", "apple"
}>
```

---

## React Pattern

```tsx
import { useTransaction, federatedLogin } from '@auth0/auth0-acul-react/login-id'

const { alternateConnections } = useTransaction()

// In JSX
{alternateConnections?.length > 0 && (
  <div className="social-section">
    <div className="divider">
      <span>Or continue with</span>
    </div>
    <div className="social-buttons">
      {alternateConnections.map(conn => (
        <SocialButton key={conn.name} connection={conn} />
      ))}
    </div>
  </div>
)}
```

```tsx
const SocialButton: React.FC<{ connection: AlternateConnection }> = ({ connection }) => {
  const [loading, setLoading] = useState(false)

  const handleClick = async () => {
    setLoading(true)
    await federatedLogin({ connection: connection.name })
    setLoading(false)
  }

  return (
    <button
      onClick={handleClick}
      disabled={loading}
      className="social-btn"
      aria-label={`Continue with ${connection.displayName}`}
    >
      {connection.iconUrl && (
        <img src={connection.iconUrl} alt="" width={20} height={20} />
      )}
      <span>Continue with {connection.displayName}</span>
    </button>
  )
}
```

---

## JS Pattern

```javascript
import LoginId from '@auth0/auth0-acul-js/login-id'
const manager = new LoginId()

function renderSocialButtons() {
  const connections = manager.transaction.alternateConnections ?? []
  if (!connections.length) return ''

  return `
    <div class="social-section">
      <div class="divider"><span>Or continue with</span></div>
      <div class="social-buttons">
        ${connections.map(conn => `
          <button
            class="social-btn"
            data-connection="${conn.name}"
            aria-label="Continue with ${conn.displayName}"
          >
            ${conn.iconUrl ? `<img src="${conn.iconUrl}" alt="" width="20" height="20" />` : ''}
            <span>Continue with ${conn.displayName}</span>
          </button>
        `).join('')}
      </div>
    </div>
  `
}

// Attach handlers after render
document.querySelectorAll('.social-btn').forEach(btn => {
  btn.addEventListener('click', async () => {
    await manager.federatedLogin({ connection: btn.dataset.connection })
  })
})
```

---

## Provider-Specific Icon SVGs

Use these inline SVGs when `iconUrl` is unavailable or for consistent brand rendering.

### Google
```html
<svg width="20" height="20" viewBox="0 0 24 24" fill="none">
  <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/>
  <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
  <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l3.66-2.84z" fill="#FBBC05"/>
  <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
</svg>
```

### GitHub
```html
<svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
  <path d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z"/>
</svg>
```

### Apple
```html
<svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
  <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/>
</svg>
```

### Microsoft
```html
<svg width="20" height="20" viewBox="0 0 24 24" fill="none">
  <rect x="1" y="1" width="10" height="10" fill="#F25022"/>
  <rect x="13" y="1" width="10" height="10" fill="#7FBA00"/>
  <rect x="1" y="13" width="10" height="10" fill="#00A4EF"/>
  <rect x="13" y="13" width="10" height="10" fill="#FFB900"/>
</svg>
```

---

## Styling the Divider

```css
.divider {
  display: flex;
  align-items: center;
  gap: 12px;
  margin: 16px 0;
}
.divider::before,
.divider::after {
  content: '';
  flex: 1;
  height: 1px;
  background: var(--color-border);
}
.divider span {
  color: var(--color-text-secondary);
  font-size: 0.875rem;
  white-space: nowrap;
}
```
