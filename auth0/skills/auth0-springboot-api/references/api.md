# API Reference & Testing

Complete reference for `com.auth0:auth0-springboot-api` configuration options and auto-configuration classes.

---

## Configuration Reference

### application.yml Properties

```yaml
auth0:
  domain: "your-tenant.auth0.com"        # Required: Auth0 tenant domain (no https://)
  audience: "https://api.example.com"     # Required: API identifier / audience
  dpop-mode: ALLOWED                      # Optional: DISABLED | ALLOWED | REQUIRED (default: ALLOWED)
  dpop-iat-offset-seconds: 300            # Optional: DPoP proof time window (default: 300)
  dpop-iat-leeway-seconds: 30             # Optional: DPoP proof time leeway (default: 30)
```

### application.properties Equivalent

```properties
auth0.domain=your-tenant.auth0.com
auth0.audience=https://api.example.com
auth0.dpopMode=ALLOWED
auth0.dpopIatOffsetSeconds=300
auth0.dpopIatLeewaySeconds=30
```

### Environment Variables

```bash
AUTH0_DOMAIN=your-tenant.auth0.com
AUTH0_AUDIENCE=https://api.example.com
AUTH0_DPOPMODE=ALLOWED
AUTH0_DPOPIATOFFSETSECONDS=300
AUTH0_DPOPIATLEEWAYSECONDS=30
```

> **Note:** Spring Boot environment variable binding removes dashes and is case-insensitive. Do not use underscores to separate words within a property name (e.g., use `AUTH0_DPOPMODE`, not `AUTH0_DPOP_MODE`).

---

## Auth0Properties

| Property | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `domain` | `String` | Yes | — | Auth0 tenant domain. Format: `your-tenant.auth0.com` (no `https://` prefix) |
| `audience` | `String` | Yes | — | API Identifier from Auth0 Dashboard |
| `dpopMode` | `DPoPMode` | No | `ALLOWED` | Controls which token types are accepted |
| `dpopIatOffsetSeconds` | `Long` | No | `300` | Maximum age of DPoP proof `iat` claim in seconds |
| `dpopIatLeewaySeconds` | `Long` | No | `30` | Additional leeway for DPoP proof time validation |
| `domains` | `List<String>` | No | — | Additional trusted Auth0 domains (for Multiple Custom Domains) |
| `cacheMaxEntries` | `Integer` | No | — | Maximum entries in the JWKS cache |
| `cacheTtlSeconds` | `Long` | No | — | TTL in seconds for JWKS cache entries |

### Auto-Configuration Beans

The SDK auto-configuration also supports custom beans:

| Bean | Description |
|------|-------------|
| `DomainResolver` | Custom domain resolution for Multiple Custom Domains (MCD). Provide a `@Bean` of type `DomainResolver` to route requests to different Auth0 domains based on the request. |
| `AuthCache` | Custom cache implementation for JWKS or token verification results. Provide a `@Bean` of type `AuthCache` to override the default in-memory cache. |

### DPoPMode Enum

| Value | Description |
|-------|-------------|
| `DPoPMode.DISABLED` | Standard JWT Bearer only — rejects DPoP tokens |
| `DPoPMode.ALLOWED` | Accept both DPoP-bound and standard Bearer tokens (default) |
| `DPoPMode.REQUIRED` | Only accept DPoP-bound tokens — rejects standard Bearer |

---

## Auto-Configuration Classes

### Auth0AutoConfiguration

Automatically creates `AuthOptions` and `AuthClient` beans from `Auth0Properties`.

```java
// AuthOptions bean — built from application.yml
@Bean
public AuthOptions authOptions(Auth0Properties properties) {
    AuthOptions.Builder builder = new AuthOptions.Builder()
        .domain(properties.getDomain())
        .audience(properties.getAudience());

    if (properties.getDpopMode() != null) {
        builder.dpopMode(properties.getDpopMode());
    }
    if (properties.getDpopIatLeewaySeconds() != null) {
        builder.dpopIatLeewaySeconds(properties.getDpopIatLeewaySeconds());
    }
    if (properties.getDpopIatOffsetSeconds() != null) {
        builder.dpopIatOffsetSeconds(properties.getDpopIatOffsetSeconds());
    }
    return builder.build();
}

// AuthClient bean — main entry point for verifying HTTP requests
@Bean
@ConditionalOnMissingBean
public AuthClient authClient(AuthOptions options) {
    return AuthClient.from(options);
}
```

### Auth0SecurityAutoConfiguration

Automatically creates the `Auth0AuthenticationFilter` bean.

```java
@Bean
@ConditionalOnMissingBean
public Auth0AuthenticationFilter authAuthenticationFilter(
        AuthClient authClient, Auth0Properties auth0Properties) {
    return new Auth0AuthenticationFilter(authClient, auth0Properties);
}
```

### Auth0AuthenticationFilter

A `OncePerRequestFilter` that:
1. Extracts the `Authorization` header
2. Calls `AuthClient.verifyRequest()` to validate the JWT (and DPoP proof if present)
3. Sets `Auth0AuthenticationToken` in the `SecurityContextHolder`
4. On failure, returns appropriate HTTP status and `WWW-Authenticate` header

---

## Auth0AuthenticationToken

Extends `AbstractAuthenticationToken`. Created after successful JWT validation.

| Method | Return Type | Description |
|--------|-------------|-------------|
| `getName()` | `String` | User ID (`sub` claim from JWT) |
| `getClaims()` | `Map<String, Object>` | All JWT claims |
| `getClaim(String claimName)` | `Object` | Specific claim value, or `null` |
| `getScopes()` | `Set<String>` | Parsed scopes from `scope` claim |
| `getAuthorities()` | `Collection<GrantedAuthority>` | `SCOPE_` prefixed authorities from JWT scopes |

**Authority mapping:** The `scope` claim `"read:data write:data"` becomes authorities `SCOPE_read:data` and `SCOPE_write:data`. If no scopes are present, a default `ROLE_USER` authority is assigned.

---

## Claims Reference

### Standard JWT Claims

| Claim | Description | Access |
|-------|-------------|--------|
| `sub` | User ID (subject) | `authentication.getName()` or `token.getClaim("sub")` |
| `scope` | Space-separated scopes | `token.getScopes()` or `token.getClaim("scope")` |
| `aud` | Audience (API identifier) | `token.getClaim("aud")` |
| `iss` | Issuer (Auth0 tenant URL) | `token.getClaim("iss")` |
| `exp` | Expiration timestamp | `token.getClaim("exp")` |
| `iat` | Issued-at timestamp | `token.getClaim("iat")` |

### Auth0-Specific Claims

| Claim | Description |
|-------|-------------|
| `permissions` | Array of RBAC permissions (if Enable RBAC is on) |
| `email` | User email (if requested in scope) |
| `https://your-domain.com/*` | Custom claims added via Auth0 Actions (namespaced) |

---

## Complete Minimal Example

```java
// src/main/java/com/example/SecurityConfig.java
@Configuration
@EnableMethodSecurity
public class SecurityConfig {

    @Bean
    SecurityFilterChain apiSecurity(
            HttpSecurity http,
            Auth0AuthenticationFilter authFilter
    ) throws Exception {
        return http
            .csrf(csrf -> csrf.disable())
            .sessionManagement(session ->
                session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/public").permitAll()
                .requestMatchers("/api/admin/**").hasAuthority("SCOPE_admin")
                .anyRequest().authenticated())
            .addFilterBefore(authFilter, UsernamePasswordAuthenticationFilter.class)
            .build();
    }
}

// src/main/java/com/example/ApiController.java
@RestController
@RequestMapping("/api")
public class ApiController {

    @GetMapping("/public")
    public ResponseEntity<Map<String, Object>> publicEndpoint() {
        return ResponseEntity.ok(Map.of("message", "Public endpoint"));
    }

    @GetMapping("/protected")
    public ResponseEntity<Map<String, Object>> protectedEndpoint(Authentication authentication) {
        Auth0AuthenticationToken token = (Auth0AuthenticationToken) authentication;
        return ResponseEntity.ok(Map.of(
            "user", authentication.getName(),
            "scopes", token.getScopes()
        ));
    }

    @GetMapping("/admin/dashboard")
    public ResponseEntity<Map<String, Object>> adminEndpoint(Authentication authentication) {
        return ResponseEntity.ok(Map.of(
            "message", "Admin access granted",
            "user", authentication.getName()
        ));
    }
}
```

```yaml
# src/main/resources/application.yml
auth0:
  domain: "your-tenant.auth0.com"
  audience: "https://my-springboot-api"

spring:
  application:
    name: auth0-api
```

---

## Testing Checklist

1. **Public endpoint returns 200 without token:**
   ```bash
   curl http://localhost:8080/api/public
   ```

2. **Protected endpoint returns 401 without token:**
   ```bash
   curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/protected
   # Expected: 401
   ```

3. **Protected endpoint returns 200 with valid token:**
   ```bash
   curl http://localhost:8080/api/protected \
     -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
   ```

4. **Scope-protected endpoint returns 403 with insufficient scope:**
   ```bash
   curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/admin/dashboard \
     -H "Authorization: Bearer TOKEN_WITHOUT_ADMIN_SCOPE"
   # Expected: 403
   ```

5. **DPoP token accepted (if dpop-mode is ALLOWED or REQUIRED):**
   ```bash
   curl http://localhost:8080/api/protected \
     -H "Authorization: DPoP YOUR_DPOP_TOKEN" \
     -H "DPoP: YOUR_DPOP_PROOF"
   ```

---

## Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| 401 `invalid_token` | Audience mismatch | Verify `auth0.audience` matches API Identifier exactly |
| 401 `invalid_issuer` | Domain has `https://` prefix | Use `your-tenant.auth0.com` format only |
| 403 Forbidden | Token missing required scope | Request token with correct scopes; check `hasAuthority` values |
| No `Auth0AuthenticationFilter` bean | Missing auto-configuration | Ensure `auth0-springboot-api` is on classpath and `auth0.domain`/`auth0.audience` are set |
| DPoP `invalid_dpop_proof` | Proof validation failed | Check DPoP proof format, `iat` claim within time window |
| Token expired | Short-lived test token | Request a fresh token from Auth0 Dashboard or CLI |
| Multiple Authorization headers | Duplicate header sent | Send exactly one `Authorization` header per request |

---

## Security Considerations

- **No client secret needed** — This library validates JWTs via JWKS (public key), not client credentials
- **Never hardcode domain or audience** — Use `application.yml` or environment variables
- **Use HTTPS in production** — Auth0 requires HTTPS for token issuance; API should also use HTTPS
- **Stateless sessions** — Always configure `SessionCreationPolicy.STATELESS` for API endpoints
- **Use minimal scopes** — Only enforce scopes your API actually needs
- **Keep packages updated** — Regularly update `auth0-springboot-api` for security patches
- **DPoP for high-security APIs** — Enable `dpop-mode: REQUIRED` to prevent token theft

---

## References

- [Auth0 Java Spring Security API Quickstart](https://auth0.com/docs/quickstart/backend/java-spring-security5)
- [SDK GitHub Repository](https://github.com/auth0/auth0-auth-java)
- [Spring Security Documentation](https://docs.spring.io/spring-security/reference/)
- [DPoP RFC 9449](https://datatracker.ietf.org/doc/html/rfc9449)
