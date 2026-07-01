# Auth0 Java MVC Common Integration Patterns

Advanced integration patterns for Java Servlet applications using `com.auth0:mvc-auth-commons`.

---

## Login and Callback Flow

### Basic Login

```java
@WebServlet(urlPatterns = {"/login"})
public class LoginServlet extends HttpServlet {

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        AuthenticationController controller = Auth0Config.getAuthController();

        String scheme = request.getScheme();
        int port = request.getServerPort();
        String redirectUrl = scheme + "://" + request.getServerName()
            + ((port == 80 || port == 443) ? "" : ":" + port) + "/callback";

        String authorizeUrl = controller.buildAuthorizeUrl(request, response, redirectUrl)
            .withScope("openid profile email")
            .build();

        response.sendRedirect(authorizeUrl);
    }
}
```

### Callback Handler

```java
@WebServlet(urlPatterns = {"/callback"})
public class CallbackServlet extends HttpServlet {

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        AuthenticationController controller = Auth0Config.getAuthController();

        try {
            Tokens tokens = controller.handle(request, response);

            // Store tokens in session
            request.getSession().setAttribute("accessToken", tokens.getAccessToken());
            request.getSession().setAttribute("idToken", tokens.getIdToken());

            // Redirect to original requested page or dashboard
            String returnTo = (String) request.getSession().getAttribute("returnTo");
            response.sendRedirect(returnTo != null ? returnTo : "/dashboard");

        } catch (IdentityVerificationException e) {
            response.sendRedirect("/login?error=" + e.getCode());
        }
    }
}
```

---

## Logout

### Complete Logout (Session + Auth0)

```java
@WebServlet(urlPatterns = {"/logout"})
public class LogoutServlet extends HttpServlet {

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        // Invalidate local session
        if (request.getSession(false) != null) {
            request.getSession().invalidate();
        }

        // Redirect to Auth0 logout endpoint
        String domain = System.getenv("AUTH0_DOMAIN");
        String clientId = System.getenv("AUTH0_CLIENT_ID");
        String scheme = request.getScheme();
        int port = request.getServerPort();
        String returnTo = scheme + "://" + request.getServerName()
            + ((port == 80 || port == 443) ? "" : ":" + port);

        String logoutUrl = String.format(
            "https://%s/v2/logout?client_id=%s&returnTo=%s",
            domain, clientId, java.net.URLEncoder.encode(returnTo, "UTF-8")
        );

        response.sendRedirect(logoutUrl);
    }
}
```

**Important:** Always invalidate the local session AND redirect to Auth0 `/v2/logout` to clear the Auth0 session.

---

## Requesting API Access Tokens

To call external APIs with an access token, include the `audience` parameter:

```java
String authorizeUrl = controller.buildAuthorizeUrl(request, response, redirectUrl)
    .withScope("openid profile email read:messages")
    .withAudience("https://my-api.example.com")
    .build();
```

The returned access token will be scoped to the specified audience:

```java
Tokens tokens = controller.handle(request, response);
String apiToken = tokens.getAccessToken();  // Use this to call your API
```

---

## Organizations Support

### Lock Login to Specific Organization

```java
String authorizeUrl = controller.buildAuthorizeUrl(request, response, redirectUrl)
    .withScope("openid profile email")
    .withOrganization("org_abc123")
    .build();
```

### Accept Organization Invitation

```java
// Extract from invitation URL query parameters
String organization = request.getParameter("organization");
String invitation = request.getParameter("invitation");

AuthorizeUrl url = controller.buildAuthorizeUrl(request, response, redirectUrl)
    .withScope("openid profile email")
    .withOrganization(organization)
    .withInvitation(invitation);

response.sendRedirect(url.build());
```

### Organization Claim in Token

After login with an organization, the ID token contains an `org_id` claim:

```java
Tokens tokens = controller.handle(request, response);
// Decode the ID token to access org_id claim
// The library validates that org_id matches if withOrganization() was used
```

---

## Multiple Custom Domains (MCD)

Use `DomainResolver` to route users to different Auth0 domains based on the request:

### Implement DomainResolver

```java
import com.auth0.DomainResolver;
import javax.servlet.http.HttpServletRequest;

public class SubdomainDomainResolver implements DomainResolver {

    @Override
    public String resolve(HttpServletRequest request) {
        String host = request.getServerName();

        if (host.startsWith("eu.")) {
            return "my-tenant-eu.custom-domain.com";
        } else if (host.startsWith("au.")) {
            return "my-tenant-au.custom-domain.com";
        }

        return System.getenv("AUTH0_DOMAIN");
    }
}
```

> **Security warning:** When resolving domains from the request, always validate against a trusted allowlist of known domains. Never use the raw request `Host` header as a domain value — an attacker could manipulate it. For single-tenant deployments, return a hardcoded domain. If behind a reverse proxy, ensure `X-Forwarded-Host` is set by a trusted proxy only.

### Configure with DomainResolver

```java
DomainResolver resolver = new SubdomainDomainResolver();
AuthenticationController controller = AuthenticationController
    .newBuilder(resolver, clientId, clientSecret)
    .build();
```

The `DomainResolver` is called on each request, so each user can be directed to the correct Auth0 custom domain.

---

## Custom Scopes and Parameters

### Request Additional Scopes

```java
AuthorizeUrl url = controller.buildAuthorizeUrl(request, response, redirectUrl)
    .withScope("openid profile email offline_access read:messages write:messages");
```

Common scopes:

| Scope | Description |
|-------|-------------|
| `openid` | Required — enables OpenID Connect |
| `profile` | User's name, nickname, picture |
| `email` | User's email and verification status |
| `offline_access` | Request a refresh token |
| Custom scopes | API-specific scopes (e.g., `read:messages`) |

### Skip to Specific Connection

```java
// Go directly to Google login (skip Universal Login selection)
AuthorizeUrl url = controller.buildAuthorizeUrl(request, response, redirectUrl)
    .withScope("openid profile email")
    .withConnection("google-oauth2");
```

### Custom Parameters

```java
AuthorizeUrl url = controller.buildAuthorizeUrl(request, response, redirectUrl)
    .withScope("openid profile email")
    .withParameter("screen_hint", "signup")     // Show signup instead of login
    .withParameter("login_hint", "user@example.com")  // Pre-fill email
    .withParameter("ui_locales", "fr");                // French UI
```

---

## Clock Skew Configuration

If your server clock drifts from Auth0 servers, token validation may fail with `a0.invalid_jwt_error`:

```java
AuthenticationController controller = AuthenticationController
    .newBuilder(domain, clientId, clientSecret)
    .withClockSkew(300)  // Allow 5 minutes of clock skew
    .build();
```

---

## Protected Routes with Authentication Filter

### Basic Authentication Filter

```java
@WebFilter(urlPatterns = {"/dashboard/*", "/api/private/*"})
public class AuthenticationFilter implements Filter {

    @Override
    public void doFilter(ServletRequest req, ServletResponse res, FilterChain chain)
            throws IOException, ServletException {
        HttpServletRequest request = (HttpServletRequest) req;
        HttpServletResponse response = (HttpServletResponse) res;
        HttpSession session = request.getSession(false);

        if (session == null || session.getAttribute("idToken") == null) {
            // Store requested URL for redirect after login
            request.getSession(true).setAttribute("returnTo", request.getRequestURI());
            response.sendRedirect("/login");
            return;
        }

        chain.doFilter(req, res);
    }

    @Override
    public void init(FilterConfig filterConfig) {}

    @Override
    public void destroy() {}
}
```

---

## Accessing User Claims

### Decode ID Token Claims

The ID token is a JWT. Decode it to access user claims:

```java
import com.auth0.jwt.JWT;
import com.auth0.jwt.interfaces.DecodedJWT;

@WebServlet(urlPatterns = {"/dashboard"})
public class DashboardServlet extends HttpServlet {

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        String idToken = (String) request.getSession().getAttribute("idToken");
        DecodedJWT jwt = JWT.decode(idToken);

        String userId = jwt.getSubject();
        String email = jwt.getClaim("email").asString();
        String name = jwt.getClaim("name").asString();
        String picture = jwt.getClaim("picture").asString();

        // Render dashboard with user info
        request.setAttribute("userId", userId);
        request.setAttribute("email", email);
        request.setAttribute("name", name);
        request.setAttribute("picture", picture);
        request.getRequestDispatcher("/WEB-INF/dashboard.jsp").forward(request, response);
    }
}
```

**Note:** Decoding with `JWT.decode()` does not verify the signature — the library already verified it during `controller.handle()`.

---

## Error Handling

### IdentityVerificationException

```java
try {
    Tokens tokens = controller.handle(request, response);
    // Success — store tokens
} catch (IdentityVerificationException e) {
    String errorCode = e.getCode();

    switch (errorCode) {
        case "a0.api_error":
            // Auth0 API error — check tenant config
            break;
        case "a0.missing_jwt_public_key_error":
            // Cannot reach JWKS — check network
            break;
        case "a0.invalid_jwt_error":
            // JWT validation failed — check clock skew
            break;
        case "a0.invalid_state":
            // State mismatch between login and callback — session may have been lost
            break;
        case "a0.missing_id_token":
            // No ID token returned — check scopes include "openid"
            break;
        case "a0.missing_access_token":
            // No access token returned
            break;
        default:
            // Other error
            break;
    }

    request.setAttribute("error", e.getMessage());
    request.getRequestDispatcher("/WEB-INF/error.jsp").forward(request, response);
}
```

### User-Denied Consent

If a user denies consent on the Auth0 login page, the callback receives `error=access_denied`. The library wraps this in `IdentityVerificationException`.

---

## HTTP Logging (Debugging)

### SDK Built-in Logging

The simplest way to enable debug logging:

```java
AuthenticationController controller = AuthenticationController
    .newBuilder(domain, clientId, clientSecret)
    .build();

controller.setLoggingEnabled(true);
```

### SLF4J / Logback

For more granular control, add SLF4J + Logback and configure in `logback.xml`:

```xml
<logger name="com.auth0" level="DEBUG" />
```

---

## Servlet API Compatibility

The SDK currently supports `javax.servlet` only. The code and README use `javax.servlet` imports:

```java
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
```

If your project uses `jakarta.servlet` (Jakarta EE 9+), this SDK is not compatible. Check for a Jakarta-specific version or consider an alternative like the Spring Boot Okta starter which supports Jakarta.

---

## Security Considerations

- **CSRF protection** — The library automatically generates and validates `state` parameter
- **Session fixation** — Regenerate session ID after login: `request.changeSessionId()`
- **Token storage** — Store tokens in server-side session only, never in cookies or HTML
- **HTTPS** — Use HTTPS in production; Auth0 requires it for callback URLs
- **Client secret** — Never expose in client-side code or commit to source control
- **Session timeout** — Configure session timeout in `web.xml`:

```xml
<session-config>
    <session-timeout>30</session-timeout> <!-- minutes -->
</session-config>
```

---

## References

- [API Reference](api.md)
- [Setup Guide](setup.md)
- [Main Skill](../SKILL.md)
