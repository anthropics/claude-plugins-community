# Auth0 Concepts & Troubleshooting

Core Auth0 concepts, terminology, troubleshooting guide, and security best practices.

---

## Application Types

Understanding which application type to choose:

| Type | Use Case | Client Secret | PKCE | Token Storage |
|------|----------|---------------|------|---------------|
| **Single Page Application (SPA)** | React, Vue, Angular, client-side apps | ❌ Not used | ✅ Required | Browser (memory/storage) |
| **Regular Web Application** | Next.js, Express, Rails, server-rendered | ✅ Required | ✅ Recommended | Server-side session |
| **Native Application** | React Native, iOS, Android, Electron | ❌ Not used | ✅ Required | Secure device storage |
| **Machine-to-Machine (M2M)** | Backend APIs, cron jobs, services | ✅ Required | ❌ Not applicable | Server environment |

### When to Use Each Type

**Single Page Application (SPA):**
- Client-side only (no backend server)
- JavaScript runs in browser
- Cannot keep secrets secure
- Examples: Vite React app, Vue CLI app

**Regular Web Application:**
- Has a backend server
- Server renders pages or handles authentication
- Can securely store secrets
- Examples: Next.js app, Express with sessions

**Native Application:**
- Mobile or desktop application
- Runs on user's device
- Cannot keep secrets secure (can be extracted)
- Examples: React Native app, iOS app, Electron app

**Machine-to-Machine (M2M):**
- No user interaction
- Server-to-server communication
- Uses Client Credentials flow
- Examples: Cron jobs, backend services, APIs calling APIs

---

## Key Terms

### Authentication Terms

| Term | Definition | Example |
|------|------------|---------|
| **Domain** | Your Auth0 tenant URL | `your-tenant.auth0.com` |
| **Client ID** | Public identifier for your app | `abc123xyz` (safe to expose) |
| **Client Secret** | Confidential secret (server-side only) | Never expose in client code! |
| **Tenant** | Your Auth0 account/instance | `your-tenant` |
| **Connection** | Authentication source | Username-Password, Google, SAML |
| **Universal Login** | Auth0's hosted login page | Recommended for best security |

### URLs and Redirects

| Term | Definition | Example |
|------|------------|---------|
| **Callback URL** | Where Auth0 redirects after login | `http://localhost:3000/callback` |
| **Logout URL** | Where Auth0 redirects after logout | `http://localhost:3000` |
| **Allowed Origins** | Domains that can make requests | `http://localhost:3000` |
| **Allowed Web Origins** | For CORS and silent auth | `http://localhost:3000` |

### Tokens

| Token | Purpose | Lifespan | Where Stored |
|-------|---------|----------|--------------|
| **Access Token** | API authorization | Short (hours) | Client or server |
| **ID Token** | User identity info (JWT) | Short (hours) | Client or server |
| **Refresh Token** | Get new access tokens | Long (days/months) | Secure storage only |

### OAuth/OIDC Terms

| Term | Definition |
|------|------------|
| **Audience** | API identifier, specifies which API the token is for |
| **Scope** | Permissions requested (e.g., `openid profile email`) |
| **PKCE** | Proof Key for Code Exchange - security for SPAs/mobile |
| **Grant Type** | OAuth flow type (Authorization Code, Client Credentials, etc.) |
| **Claims** | Information in a token (email, name, roles, etc.) |

---

## OAuth Flows

### Authorization Code Flow with PKCE

**Used by:** SPAs, Native apps

**How it works:**
1. App redirects to Auth0 login
2. User authenticates
3. Auth0 redirects back with authorization code
4. App exchanges code for tokens (with PKCE proof)

**Security:** PKCE prevents authorization code interception

### Authorization Code Flow (with Secret)

**Used by:** Regular web applications (server-side)

**How it works:**
1. App redirects to Auth0 login
2. User authenticates
3. Auth0 redirects back with authorization code
4. Server exchanges code for tokens using client secret

**Security:** Client secret never exposed to browser

### Client Credentials Flow

**Used by:** M2M applications

**How it works:**
1. Service authenticates with client ID + secret
2. Receives access token
3. Uses token to call APIs

**Security:** No user involved, service-to-service only

---

## Troubleshooting

### Common Issues

| Issue | Symptom | Solution |
|-------|---------|----------|
| **Invalid callback URL** | Error after login redirect | Add callback URL in Auth0 dashboard app settings |
| **Invalid state** | Error during login | Clear browser storage and cookies, try again |
| **Client authentication failed** | 401 error | Verify client ID and secret are correct |
| **Missing required parameter** | Auth0 error message | Check environment variables are loaded |
| **Unauthorized when calling API** | 401 from API | Ensure `audience` is configured in auth config |
| **Session not created** | Login works but no session | Check `AUTH0_SECRET` is set (server-side apps) |
| **CORS errors** | Browser blocks requests | Add your domain to Allowed Web Origins |
| **Token expired** | 401 after some time | Implement token refresh or re-authentication |

### Debugging Steps

1. **Check Auth0 Logs**
   - Go to Auth0 Dashboard → Monitoring → Logs
   - Or use: `auth0 logs tail`

2. **Verify Environment Variables**
   ```bash
   # Check variables are loaded
   console.log(process.env.AUTH0_DOMAIN)
   console.log(import.meta.env.VITE_AUTH0_DOMAIN)
   ```

3. **Inspect Network Traffic**
   - Open browser DevTools → Network tab
   - Look for failed auth requests
   - Check response errors

4. **Clear Auth State**
   ```bash
   # Clear browser storage
   localStorage.clear()
   sessionStorage.clear()
   # Clear cookies for your domain
   ```

5. **Test with Auth0 CLI**
   ```bash
   # Test login flow
   auth0 test login <client-id>

   # Get test token
   auth0 test token <client-id>
   ```

---

## Security Best Practices

### ✅ Recommended Practices

1. **Use HTTPS in Production**
   - Auth0 requires HTTPS callback URLs
   - Never use HTTP in production

2. **Never Commit Secrets**
   - Add `.env` files to `.gitignore`
   - Use secret management tools (AWS Secrets Manager, etc.)

3. **Rotate Secrets Regularly**
   - Update `AUTH0_SECRET` every 90 days
   - Rotate client secrets periodically

4. **Use PKCE**
   - Required for SPAs and native apps
   - Enabled by default in modern Auth0 SDKs

5. **Validate Tokens on Backend**
   - Never trust client-side validation
   - Always verify JWT signature server-side

6. **Configure CORS Properly**
   - Only add your actual domains to Allowed Origins
   - Don't use wildcards (`*`) in production

7. **Use Refresh Tokens Wisely**
   - Enable refresh token rotation
   - Store securely (not in localStorage)

8. **Implement Rate Limiting**
   - Protect Auth0 endpoints from abuse
   - Use Auth0's anomaly detection

9. **Enable MFA for Admin Accounts**
   - Require MFA for Auth0 dashboard access
   - Use hardware security keys when possible

10. **Monitor Auth0 Logs**
    - Set up log streaming to SIEM
    - Alert on suspicious activity

### ❌ Security Anti-Patterns

1. **Hardcoding Credentials**
   ```javascript
   // ❌ NEVER DO THIS
   const clientSecret = "abc123secret";
   ```

2. **Exposing Client Secret in Frontend**
   ```javascript
   // ❌ NEVER in browser code
   clientSecret: process.env.CLIENT_SECRET
   ```

3. **Using Client Secret in SPAs**
   - SPAs cannot keep secrets
   - Use SPA application type instead

4. **Storing Tokens in localStorage (Sensitive Apps)**
   - XSS can steal tokens
   - Consider in-memory storage or httpOnly cookies

5. **Skipping Token Validation**
   ```javascript
   // ❌ Don't trust tokens blindly
   const user = jwt.decode(token);  // No validation!

   // ✅ Always verify
   const user = jwt.verify(token, publicKey, options);
   ```

6. **Using HTTP in Production**
   - Tokens sent over HTTP can be intercepted
   - Always use HTTPS

---

## Common Auth0 Configurations

### Recommended Scopes

**For user authentication:**
```
openid profile email
```

**For API access:**
```
openid profile email read:users write:users
```

**Minimal:**
```
openid
```

### Token Lifespans

**Recommended values:**

| Token Type | Development | Production |
|------------|-------------|------------|
| Access Token | 1 hour | 1 hour |
| ID Token | 1 hour | 1 hour |
| Refresh Token | 30 days | 30 days |

**Note:** Shorter is more secure, but requires more frequent renewal.

### Session Configuration

**Express.js example:**
```javascript
app.use(auth({
  secret: process.env.AUTH0_SECRET,
  session: {
    rolling: true,              // Extend session on activity
    rollingDuration: 86400,     // 24 hours
    absoluteDuration: 604800    // 7 days max
  }
}));
```

---

## Migrating Between Application Types

### From SPA to Regular Web App

**Why:** Need server-side rendering, better security for secrets

**Changes needed:**
1. Create new Auth0 app (type: Regular Web App)
2. Add client secret to environment (server-side only)
3. Change callback URL pattern (usually `/api/auth/callback`)
4. Update SDK (e.g., from `auth0-react` to `nextjs-auth0`)
5. Move auth logic to server

### From Regular Web App to SPA

**Why:** Want client-side only, serverless deployment

**Changes needed:**
1. Create new Auth0 app (type: SPA)
2. Remove client secret (not used in SPAs)
3. Enable PKCE
4. Update callback URLs (no `/api/auth/` prefix)
5. Update SDK to client-side SDK

---

## Advanced Concepts

### Organizations (B2B)

Multi-tenant B2B applications:
- Separate login domains per organization
- Organization-specific branding
- Organization invitation flows

**Learn more:** `auth0-organizations` skill

### Multi-Factor Authentication (MFA)

Require additional verification:
- TOTP (Google Authenticator)
- SMS, Email, Push
- WebAuthn (security keys, biometrics)
- Step-up authentication for sensitive operations

**Learn more:** `auth0-mfa` skill

### Passwordless Authentication

Login without passwords:
- Magic links via email
- SMS one-time codes
- WebAuthn / Passkeys

**Learn more:** `auth0-passkeys` skill

### Custom Domains

Use your own domain for Auth0:
- `auth.myapp.com` instead of `tenant.auth0.com`
- Better branding
- First-party cookies

**Setup:** Auth0 Dashboard → Branding → Custom Domains

---

## References

- [Auth0 Docs - Application Settings](https://auth0.com/docs/get-started/applications)
- [Auth0 Docs - Tokens](https://auth0.com/docs/secure/tokens)
- [OAuth 2.0 Specification](https://oauth.net/2/)
- [OpenID Connect Specification](https://openid.net/connect/)
- [PKCE RFC 7636](https://tools.ietf.org/html/rfc7636)
