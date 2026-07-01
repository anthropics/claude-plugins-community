# Auth0 Spring Boot API Integration Patterns

Advanced integration patterns for Spring Boot API applications using `auth0-springboot-api`.

---

## Scope-Based Authorization

The library maps JWT scopes to Spring Security authorities with a `SCOPE_` prefix. A token with `scope: "read:messages write:messages"` produces authorities `SCOPE_read:messages` and `SCOPE_write:messages`.

### Option 1: Security Filter Chain (Recommended)

Define scope requirements in your security configuration:

```java
@Configuration
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
                .requestMatchers("/api/users/**").hasAuthority("SCOPE_read:users")
                .anyRequest().authenticated())
            .addFilterBefore(authFilter, UsernamePasswordAuthenticationFilter.class)
            .build();
    }
}
```

### Option 2: Method-Level Security with @PreAuthorize

Requires `@EnableMethodSecurity` on a configuration class:

```java
@Configuration
@EnableMethodSecurity
public class MethodSecurityConfig {
    // Enables @PreAuthorize annotations
}
```

```java
@RestController
@RequestMapping("/api/users")
public class UserManagementController {

    @GetMapping
    @PreAuthorize("hasAuthority('SCOPE_read:users')")
    public ResponseEntity<List<User>> getUsers() {
        return ResponseEntity.ok(userService.getAllUsers());
    }

    @PostMapping
    @PreAuthorize("hasAuthority('SCOPE_write:users')")
    public ResponseEntity<User> createUser(@RequestBody User user) {
        return ResponseEntity.ok(userService.createUser(user));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAuthority('SCOPE_delete:users')")
    public ResponseEntity<Void> deleteUser(@PathVariable String id) {
        userService.deleteUser(id);
        return ResponseEntity.noContent().build();
    }
}
```

### Option 3: Programmatic Scope Check

Use `getScopes()` on the token for custom logic:

```java
@GetMapping("/admin")
public ResponseEntity<Map<String, Object>> adminEndpoint(Authentication authentication) {
    if (authentication instanceof Auth0AuthenticationToken auth0Token) {
        Set<String> scopes = auth0Token.getScopes();

        if (!scopes.contains("admin") || !scopes.contains("read:admin")) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                .body(Map.of("error", "insufficient_scope"));
        }

        return ResponseEntity.ok(Map.of("message", "Admin access granted"));
    }

    return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
}
```

### Define Permissions in Auth0

1. Go to Auth0 Dashboard → Applications → APIs
2. Select your API
3. Click the **Permissions** tab
4. Add permissions matching your scope names (e.g., `read:users`, `write:users`)

### Request Tokens with Scopes

```bash
curl -X POST https://your-tenant.auth0.com/oauth/token \
  -H "Content-Type: application/json" \
  -d '{
    "client_id": "YOUR_CLIENT_ID",
    "client_secret": "YOUR_CLIENT_SECRET",
    "audience": "https://my-springboot-api",
    "grant_type": "client_credentials",
    "scope": "read:users write:users"
  }'
```

---

## DPoP Authentication

[DPoP](https://www.rfc-editor.org/rfc/rfc9449.html) (Demonstrating Proof of Possession) binds tokens to a specific client key pair, preventing token theft.

### Configuration Modes

#### ALLOWED Mode (Default)

Accepts both Bearer and DPoP tokens:

```yaml
auth0:
  domain: "your-tenant.auth0.com"
  audience: "https://my-springboot-api"
  dpop-mode: ALLOWED
```

#### REQUIRED Mode

Only accepts DPoP tokens — rejects standard Bearer:

```yaml
auth0:
  domain: "your-tenant.auth0.com"
  audience: "https://my-springboot-api"
  dpop-mode: REQUIRED
```

#### DISABLED Mode

Standard JWT Bearer only — rejects DPoP tokens:

```yaml
auth0:
  domain: "your-tenant.auth0.com"
  audience: "https://my-springboot-api"
  dpop-mode: DISABLED
```

### Fine-Tuning DPoP Time Validation (Optional)

The defaults work for most use cases. Only adjust these if you need to handle clock skew or network delays:

```yaml
auth0:
  domain: "your-tenant.auth0.com"
  audience: "https://my-springboot-api"
  dpop-mode: ALLOWED
  dpop-iat-offset-seconds: 300  # Optional: max age of DPoP proof (default: 300)
  dpop-iat-leeway-seconds: 30   # Optional: additional time leeway (default: 30)
```

### How DPoP Works in Controllers

DPoP validation is handled by the `Auth0AuthenticationFilter` before the request reaches your controller. Your controller code is the same regardless of whether the client used Bearer or DPoP:

```java
@GetMapping("/sensitive")
public ResponseEntity<Map<String, Object>> sensitiveEndpoint(Authentication authentication) {
    // Works the same for both Bearer and DPoP tokens
    if (authentication instanceof Auth0AuthenticationToken auth0Token) {
        return ResponseEntity.ok(Map.of(
            "user", authentication.getName(),
            "scopes", auth0Token.getScopes(),
            "message", "Access granted"
        ));
    }
    return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
}
```

### DPoP WWW-Authenticate Headers

The library automatically generates RFC-compliant `WWW-Authenticate` headers on failures:

```http
# ALLOWED mode (default)
WWW-Authenticate: Bearer realm="api", DPoP algs="ES256"

# REQUIRED mode
WWW-Authenticate: DPoP algs="ES256"

# DPoP-specific errors
WWW-Authenticate: DPoP error="invalid_dpop_proof", error_description="DPoP proof validation failed"
```

### Enable DPoP on Auth0 API

1. Go to Auth0 Dashboard → Applications → APIs
2. Select your API
3. Enable DPoP binding requirement

---

## Accessing User Claims

### From Controller Parameter

```java
@GetMapping("/profile")
public ResponseEntity<Map<String, Object>> getUserProfile(Authentication authentication) {
    if (authentication instanceof Auth0AuthenticationToken auth0Token) {
        return ResponseEntity.ok(Map.of(
            "sub", String.valueOf(auth0Token.getClaim("sub")),
            "email", String.valueOf(auth0Token.getClaim("email")),
            "scope", String.valueOf(auth0Token.getClaim("scope")),
            "scopes", auth0Token.getScopes()
        ));
    }
    return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
}
```

### Common JWT Claims

| Claim | Description |
|-------|-------------|
| `sub` | User ID (subject) |
| `scope` | Space-separated list of granted scopes |
| `aud` | Audience (your API identifier) |
| `iss` | Issuer (your Auth0 tenant URL) |
| `exp` | Expiration timestamp |
| `iat` | Issued-at timestamp |

Custom claims added via Auth0 Actions use namespaced keys, e.g., `https://your-domain.com/role`.

---

## Error Handling

### BaseAuthException Hierarchy

The library uses `BaseAuthException` subclasses for different error conditions:

| Exception | HTTP Status | Cause |
|-----------|-------------|-------|
| `MissingAuthorizationException` | 400 | No or multiple `Authorization` headers |
| `VerifyAccessTokenException` | 401 | JWT validation failed (expired, bad signature, wrong audience) |
| `InvalidAuthSchemeException` | 400 | Wrong auth scheme for configured DPoP mode |
| `InvalidDpopProofException` | 400 | DPoP proof validation failed |
| `InsufficientScopeException` | 403 | Valid token but missing required scope |

The `Auth0AuthenticationFilter` handles all exceptions automatically, setting the appropriate HTTP status and `WWW-Authenticate` header. No custom exception handling is needed in controllers for auth errors.

### Custom Error Responses

For non-auth errors in your controllers, use standard Spring patterns:

```java
@ExceptionHandler(Exception.class)
public ResponseEntity<Map<String, Object>> handleError(Exception e) {
    return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
        .body(Map.of("error", e.getMessage()));
}
```

### Standard Error Responses

| Status | Cause | Fix |
|--------|-------|-----|
| 401 | Missing or invalid token | Include valid `Authorization: Bearer <token>` header |
| 401 | Expired token | Request a fresh access token |
| 401 | Wrong audience | Token's `aud` claim must match your API Identifier |
| 403 | Insufficient scope | Token must include required scopes |

---

## Mixed Public and Protected Endpoints

```java
@RestController
@RequestMapping("/api")
public class MixedController {

    // Public - no auth needed
    @GetMapping("/public")
    public ResponseEntity<Map<String, Object>> publicEndpoint() {
        return ResponseEntity.ok(Map.of("message", "Public endpoint"));
    }

    // Protected - requires valid JWT
    @GetMapping("/private")
    public ResponseEntity<Map<String, Object>> privateEndpoint(Authentication authentication) {
        return ResponseEntity.ok(Map.of(
            "message", "Private endpoint",
            "user", authentication.getName()
        ));
    }

    // Protected with scope
    @GetMapping("/messages")
    @PreAuthorize("hasAuthority('SCOPE_read:messages')")
    public ResponseEntity<Map<String, Object>> messagesEndpoint() {
        return ResponseEntity.ok(Map.of("messages", List.of("Hello", "World")));
    }
}
```

---

## CORS Configuration

For APIs consumed by browser-based SPAs, configure CORS **before** the auth filter:

```java
@Configuration
public class SecurityConfig {

    @Bean
    SecurityFilterChain apiSecurity(
            HttpSecurity http,
            Auth0AuthenticationFilter authFilter
    ) throws Exception {
        return http
            .cors(cors -> cors.configurationSource(corsConfigurationSource()))
            .csrf(csrf -> csrf.disable())
            .sessionManagement(session ->
                session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/public").permitAll()
                .anyRequest().authenticated())
            .addFilterBefore(authFilter, UsernamePasswordAuthenticationFilter.class)
            .build();
    }

    @Bean
    CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOrigins(List.of("http://localhost:3000"));
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE"));
        config.setAllowedHeaders(List.of("Authorization", "Content-Type", "DPoP"));
        config.setAllowCredentials(true);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/api/**", config);
        return source;
    }
}
```

---

## Testing

### Integration Testing with MockMvc

```java
@SpringBootTest
@AutoConfigureMockMvc
class ApiControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void publicEndpoint_returns200() throws Exception {
        mockMvc.perform(get("/api/public"))
            .andExpect(status().isOk());
    }

    @Test
    void protectedEndpoint_withoutToken_returns401() throws Exception {
        mockMvc.perform(get("/api/protected"))
            .andExpect(status().isUnauthorized());
    }
}
```

### Testing with curl

```bash
# Get a test token
TOKEN=$(auth0 test token --audience https://my-springboot-api --json | jq -r '.access_token')

# Test protected endpoint
curl http://localhost:8080/api/protected \
  -H "Authorization: Bearer $TOKEN"
```

---

## Security Considerations

- **Stateless sessions** — Always use `SessionCreationPolicy.STATELESS` for API endpoints
- **No client secret** — This library validates JWTs via JWKS; no client secret is stored or needed
- **CORS before auth** — Configure CORS middleware before the auth filter in the security chain
- **Use HTTPS in production** — Auth0 requires HTTPS for token issuance
- **Minimal scopes** — Only enforce scopes your API actually needs
- **DPoP for high-security** — Enable `dpop-mode: REQUIRED` for APIs handling sensitive data

---

## References

- [API Reference](api.md)
- [Setup Guide](setup.md)
- [Main Skill](../SKILL.md)
