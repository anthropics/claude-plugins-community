# Auth0 Java MVC Common API Reference

Complete API reference for `com.auth0:mvc-auth-commons`.

---

## AuthenticationController

Main entry point for Auth0 authentication in Java Servlet applications.

### Builder

```java
AuthenticationController.newBuilder(String domain, String clientId, String clientSecret)
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `domain` | `String` | Yes | Auth0 tenant domain (no `https://` prefix) |
| `clientId` | `String` | Yes | Application Client ID |
| `clientSecret` | `String` | Yes | Application Client Secret |

**Builder with DomainResolver (MCD):**

```java
AuthenticationController.newBuilder(DomainResolver resolver, String clientId, String clientSecret)
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `resolver` | `DomainResolver` | Yes | Resolves domain per request for Multiple Custom Domains |
| `clientId` | `String` | Yes | Application Client ID |
| `clientSecret` | `String` | Yes | Application Client Secret |

### Builder Configuration Methods

| Method | Description |
|--------|-------------|
| `.withResponseType("code")` | Set OAuth response_type (default: `code`) |
| `.withJwkProvider(JwkProvider)` | Custom JWK provider for token verification |
| `.withClockSkew(int)` | Clock skew tolerance in seconds for token validation (default: 60) |
| `.withHttpOptions(HttpOptions)` | HTTP proxy/timeout configuration |
| `.withCookiePath(String)` | Cookie path attribute |
| `.withAuthenticationMaxAge(Integer)` | Validates `auth_time` claim in the ID token |
| `.withLegacySameSiteCookie(boolean)` | Controls SameSite=None fallback cookie (default: `true`) |
| `.withOrganization(String)` | Sends `organization` to `/authorize` **and** validates `org_id`/`org_name` claim in the returned ID token via `IdTokenVerifier`. If the value starts with `org_`, validates `org_id`; otherwise validates `org_name` (case-insensitive). Throws `TokenValidationException` on mismatch. |
| `.withInvitation(String)` | Sends `invitation` parameter to `/authorize` (no callback validation) |
| `.build()` | Build the `AuthenticationController` instance |

> **Note:** `Builder.withOrganization()` does two things: it passes the `organization` parameter to `/authorize` (via `AuthorizeUrl`) **and** validates the org claim in the returned token. `AuthorizeUrl.withOrganization()` only sends the parameter to `/authorize` without any token validation. When using `Builder.withOrganization()`, you do not need to also call `AuthorizeUrl.withOrganization()` — the Builder handles both automatically.

### Instance Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `buildAuthorizeUrl(request, response, redirectUrl)` | `AuthorizeUrl` | Build `/authorize` URL with CSRF state |
| `handle(request, response)` | `Tokens` | Exchange authorization code for tokens |
| `buildAuthorizeUrl(request, redirectUrl)` | `AuthorizeUrl` | **Deprecated** — use the 3-argument version with response |
| `handle(request)` | `Tokens` | **Deprecated** — use the 2-argument version with response |

---

## AuthorizeUrl

Fluent builder for constructing the Auth0 `/authorize` redirect URL.

### Methods

| Method | Parameter | Description |
|--------|-----------|-------------|
| `.withScope(String)` | `"openid profile email"` | Space-separated scopes to request |
| `.withAudience(String)` | `"https://my-api"` | API audience for access token |
| `.withOrganization(String)` | `"org_xxx"` | Lock login to specific Organization |
| `.withInvitation(String)` | `"invite_xxx"` | Accept Organization invitation |
| `.withConnection(String)` | `"google-oauth2"` | Skip to specific identity provider |
| `.withParameter(String, String)` | key, value | Add any custom `/authorize` parameter. **Throws `IllegalArgumentException` for `state`, `nonce`, `response_type`, `redirect_uri` — use dedicated methods instead.** |
| `.withNonce(String)` | nonce value | Set a custom nonce for ID token validation |
| `.withSecureCookie(boolean)` | `true`/`false` | Set the Secure flag on state/nonce cookies |
| `.withState(String)` | state value | Custom state parameter (overrides CSRF state) |
| `.build()` | — | Returns the complete authorize URL string |

**Example:**

```java
String authorizeUrl = controller.buildAuthorizeUrl(request, response, redirectUrl)
    .withScope("openid profile email")
    .withAudience("https://my-api.example.com")
    .withOrganization("org_abc123")
    .build();
```

---

## Tokens

Holds the tokens returned after a successful authentication.

### Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `getAccessToken()` | `String` | OAuth2 access token |
| `getIdToken()` | `String` | OpenID Connect ID token (JWT) |
| `getRefreshToken()` | `String` | Refresh token (requires `offline_access` scope) |
| `getType()` | `String` | Token type (usually "Bearer") |
| `getExpiresIn()` | `Long` | Token lifetime in seconds |
| `getDomain()` | `String` | Auth0 domain that issued the tokens |
| `getIssuer()` | `String` | Token issuer URL |

---

## DomainResolver

Interface for Multiple Custom Domains (MCD) support.

```java
public interface DomainResolver {
    String resolve(HttpServletRequest request);
}
```

### Implementation Example

```java
public class SubdomainDomainResolver implements DomainResolver {
    @Override
    public String resolve(HttpServletRequest request) {
        String host = request.getServerName();
        if (host.startsWith("eu.")) {
            return "my-tenant-eu.auth0.com";
        }
        return "my-tenant.auth0.com";
    }
}
```

---

## IdentityVerificationException

Thrown when authentication fails during callback handling.

### Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `getCode()` | `String` | Error code identifier |
| `getMessage()` | `String` | Human-readable error message |
| `isAPIError()` | `boolean` | Whether the error came from the Auth0 API |
| `isJWTError()` | `boolean` | Whether the error is a JWT validation failure |

### Error Codes

| Code | Description |
|------|-------------|
| `a0.api_error` | Auth0 API returned an error |
| `a0.missing_jwt_public_key_error` | Could not retrieve JWKS public key |
| `a0.invalid_jwt_error` | JWT validation failed (bad signature, expired, wrong audience) |

---

## InvalidRequestException

Extends `IdentityVerificationException`. Thrown when the callback request itself is invalid (e.g., state mismatch, missing tokens).

### Error Codes

| Code | Description |
|------|-------------|
| `a0.invalid_state` | State parameter mismatch between login and callback |
| `a0.missing_id_token` | No ID token returned |
| `a0.missing_access_token` | No access token returned |

Since `InvalidRequestException` extends `IdentityVerificationException`, it is caught by the same `catch` block. Use `getCode()` to distinguish specific error conditions.

---

## Environment Variable Configuration

| Variable | Required | Description |
|----------|----------|-------------|
| `AUTH0_DOMAIN` | Yes | Auth0 tenant domain (e.g., `your-tenant.auth0.com`) |
| `AUTH0_CLIENT_ID` | Yes | Application Client ID from Auth0 Dashboard |
| `AUTH0_CLIENT_SECRET` | Yes | Application Client Secret from Auth0 Dashboard |

### Reading Environment Variables

```java
String domain = System.getenv("AUTH0_DOMAIN");
String clientId = System.getenv("AUTH0_CLIENT_ID");
String clientSecret = System.getenv("AUTH0_CLIENT_SECRET");
```

Or via servlet context parameters in `web.xml`:

```xml
<context-param>
    <param-name>auth0.domain</param-name>
    <param-value>${AUTH0_DOMAIN}</param-value>
</context-param>
<context-param>
    <param-name>auth0.clientId</param-name>
    <param-value>${AUTH0_CLIENT_ID}</param-value>
</context-param>
<context-param>
    <param-name>auth0.clientSecret</param-name>
    <param-value>${AUTH0_CLIENT_SECRET}</param-value>
</context-param>
```

---

## Standard OIDC Claims (from ID Token)

| Claim | Description |
|-------|-------------|
| `sub` | User ID (subject) |
| `name` | Full name |
| `email` | Email address |
| `email_verified` | Whether email is verified |
| `picture` | Profile picture URL |
| `nickname` | User nickname |
| `updated_at` | Last profile update timestamp |

Custom claims added via Auth0 Actions use namespaced keys, e.g., `https://your-domain.com/roles`.

---

## Testing Checklist

- [ ] Login redirects to Auth0 Universal Login page
- [ ] Callback servlet exchanges code for tokens successfully
- [ ] Session stores tokens after successful login
- [ ] Protected routes redirect to `/login` when no session exists
- [ ] Protected routes allow access when session has valid tokens
- [ ] Logout invalidates session and redirects to Auth0 logout endpoint
- [ ] Error handling catches `IdentityVerificationException` on callback
- [ ] Environment variables are used (no hardcoded credentials)
- [ ] Callback URL in code matches Auth0 Dashboard configuration
- [ ] `openid` scope is always included in authorize request

### Test with curl

```bash
# Start the application
./gradlew appRun  # or mvn jetty:run

# Open login in browser (redirects to Auth0)
open http://localhost:3000/login

# After login, check session cookie is set
curl -v http://localhost:3000/dashboard --cookie "JSESSIONID=your-session-id"
```

---

## Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| `a0.invalid_jwt_error` on callback | Clock skew between server and Auth0 | Use `.withClockSkew(300)` on builder |
| `a0.missing_jwt_public_key_error` | Cannot reach Auth0 JWKS endpoint | Check network/firewall, verify domain |
| Redirect loop on callback | Callback URL not registered in Auth0 | Add exact callback URL to Allowed Callback URLs |
| `state` parameter mismatch | Session lost between login and callback | Ensure same session across redirect (check cookie settings) |
| No refresh token returned | Missing `offline_access` scope | Add `offline_access` to `.withScope()` |

---

## Security Considerations

- **Never hardcode credentials** — Always use environment variables or secret management
- **Always include `openid` scope** — Required for ID token and user identification
- **Use HTTPS in production** — Auth0 requires HTTPS for callback URLs in production
- **Validate state parameter** — The library handles CSRF via state automatically; do not disable
- **Invalidate session on logout** — Always call `session.invalidate()` before Auth0 logout redirect
- **Rotate client secret** — If secret is compromised, rotate in Auth0 Dashboard immediately
- **Store tokens server-side only** — Never expose tokens to the browser via cookies or HTML

---

## References

- [Auth0 Java Web App Quickstart](https://auth0.com/docs/quickstart/webapp/java)
- [SDK GitHub Repository](https://github.com/auth0/auth0-java-mvc-common)
- [Auth0 Universal Login](https://auth0.com/docs/authenticate/login/auth0-universal-login)
- [Authorization Code Flow](https://auth0.com/docs/get-started/authentication-and-authorization-flow/authorization-code-flow)
