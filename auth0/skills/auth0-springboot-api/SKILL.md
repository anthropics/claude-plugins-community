---
name: auth0-springboot-api
description: >
  Use when protecting Spring Boot API endpoints with JWT Bearer token validation, scope-based authorization, or DPoP binding. Integrates com.auth0:auth0-springboot-api for REST APIs receiving access tokens.
license: Apache-2.0
metadata:
  author: Auth0 <support@auth0.com>
  version: '1.0.0'
  openclaw:
    emoji: "\U0001F510"
    homepage: https://github.com/auth0/agent-skills
---

# Auth0 Spring Boot API Integration

Protect Spring Boot API endpoints with JWT access token validation using `com.auth0:auth0-springboot-api`. Features auto-configuration, scope-based authorization, and built-in DPoP (RFC 9449) support.

---

> **Agent instruction:** Before providing SDK setup instructions, fetch the latest release version by running:
> ```bash
> gh api repos/auth0/auth0-auth-java/releases/latest --jq '.tag_name'
> ```
> Use the returned version in all dependency lines instead of any hardcoded version below. If the API call fails (e.g., no releases yet), use `1.0.0-beta.1`.

## Prerequisites

- Java 17+ and Spring Boot 3.2+
- Maven 3.6+ or Gradle 7+
- Auth0 API configured (not Application — must be API resource)
- If you don't have Auth0 set up yet, use the `auth0-quickstart` skill first

## When NOT to Use

| Use Case | Recommended Skill |
|----------|------------------|
| Server-rendered web applications (Spring MVC with sessions) | Use `auth0-java` for Spring Boot web apps with login UI |
| Single Page Applications | Use `auth0-react`, `auth0-vue`, or `auth0-angular` for client-side auth |
| Mobile applications | Use `auth0-android` or `auth0-swift` for native mobile |
| Non-Spring Java APIs | Use `auth0-spring-security-api` for plain Spring Security |

---

## Quick Start Workflow

> **Agent instruction:** If the user's prompt already provides Auth0 credentials (domain, audience), use them directly — skip the bootstrap script and credential questions. Only offer setup options when credentials are missing.

### 1. Install SDK

**Gradle (build.gradle):**

```groovy
implementation 'com.auth0:auth0-springboot-api:1.0.0-beta.1'
```

**Maven (pom.xml):**

```xml
<dependency>
    <groupId>com.auth0</groupId>
    <artifactId>auth0-springboot-api</artifactId>
    <version>1.0.0-beta.1</version>
</dependency>
```

### 2. Create Auth0 API

You need an **API** (not Application) in Auth0.

> **STOP — ask the user before proceeding.**
>
> Ask exactly this question and wait for their answer before doing anything else:
>
> > "How would you like to create the Auth0 API resource?
> > 1. **Automated** — I'll run Auth0 CLI scripts that create the resource and write the values to your application.yml automatically.
> > 2. **Manual** — You create the API yourself in the Auth0 Dashboard (or via `auth0 apis create`) and provide me the Domain and Audience.
> >
> > Which do you prefer? (1 = Automated / 2 = Manual)"
>
> Do NOT proceed to any setup steps until the user has answered. Do NOT default to manual.

**If the user chose Automated**, follow the [Setup Guide](references/setup.md) for complete CLI scripts. The automated path writes `application.yml` for you — skip Step 3 below and proceed directly to Step 4.

**If the user chose Manual**, follow the [Setup Guide](references/setup.md) (Manual Setup section). Then continue with Step 3.

Quick reference for manual API creation:

```bash
# Using Auth0 CLI
auth0 apis create \
  --name "My Spring Boot API" \
  --identifier https://my-springboot-api
```

Or create manually in Auth0 Dashboard → Applications → APIs

### 3. Configure application.yml

```yaml
auth0:
  domain: "your-tenant.auth0.com"
  audience: "https://my-springboot-api"
```

**Important:** Domain must NOT include `https://`. The library constructs the issuer URL automatically.

Or use `application.properties`:

```properties
auth0.domain=your-tenant.auth0.com
auth0.audience=https://my-springboot-api
```

### 4. Configure Spring Security

```java
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
                .requestMatchers("/api/protected").authenticated()
                .requestMatchers("/api/admin/**").hasAuthority("SCOPE_admin")
                .anyRequest().authenticated())
            .addFilterBefore(authFilter, UsernamePasswordAuthenticationFilter.class)
            .build();
    }
}
```

### 5. Protect Endpoints

```java
@RestController
@RequestMapping("/api")
public class ApiController {

    @GetMapping("/public")
    public ResponseEntity<Map<String, Object>> publicEndpoint() {
        return ResponseEntity.ok(Map.of("message", "Public endpoint - no token required"));
    }

    @GetMapping("/protected")
    public ResponseEntity<Map<String, Object>> protectedEndpoint(Authentication authentication) {
        Auth0AuthenticationToken token = (Auth0AuthenticationToken) authentication;
        return ResponseEntity.ok(Map.of(
            "user", authentication.getName(),
            "email", token.getClaim("email"),
            "scopes", token.getScopes()
        ));
    }
}
```

### 6. Test API

> **Agent instruction:** After writing all code, verify the build succeeds:
> ```bash
> ./gradlew bootRun
> ```
> or `./mvnw spring-boot:run`. If build fails, diagnose and fix. After 5-6 failed attempts, use `AskUserQuestion` to get help.

Test public endpoint:

```bash
curl http://localhost:8080/api/public
```

Test protected endpoint (requires access token):

```bash
curl http://localhost:8080/api/protected \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

Get a test token via Client Credentials flow or Auth0 Dashboard → APIs → Test tab.

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Domain includes `https://` | Use `your-tenant.auth0.com` format only — no scheme prefix |
| Audience doesn't match API Identifier | Must exactly match the API Identifier set in Auth0 Dashboard |
| Created Application instead of API in Auth0 | Must create API resource in Auth0 Dashboard → Applications → APIs |
| Missing `addFilterBefore` in SecurityConfig | `Auth0AuthenticationFilter` must be added before `UsernamePasswordAuthenticationFilter` |
| Using ID token instead of access token | Must use **access token** for API auth, not ID token |
| Checking `scope` claim in wrong format | Scopes map to `SCOPE_` prefixed authorities: use `hasAuthority("SCOPE_read:data")` |
| Spring Boot env var binding | Use `AUTH0_DOMAIN` not `AUTH0_DOMAIN` with underscores inside property names; Spring removes dashes and is case-insensitive |

---

## Scope-Based Authorization

See [Integration Guide](references/integration.md) for defining and enforcing scope-based access control via filter chain, `@PreAuthorize`, or programmatic checks.

---

## DPoP Support

Built-in proof-of-possession token binding per RFC 9449. See [Integration Guide](references/integration.md) for configuration modes (DISABLED, ALLOWED, REQUIRED).

---

## Related Skills

- `auth0-quickstart` — Basic Auth0 setup and account creation
- `auth0-java` — Spring Boot web apps with login UI (Regular Web Application)

---

## Quick Reference

**Configuration Properties (`application.yml`):**
- `auth0.domain` — Auth0 tenant domain, no `https://` prefix (required)
- `auth0.audience` — API Identifier from Auth0 API settings (required)
- `auth0.dpop-mode` — DPoP mode: `DISABLED`, `ALLOWED` (default), `REQUIRED`
- `auth0.dpop-iat-offset-seconds` — DPoP proof time window (default: 300)
- `auth0.dpop-iat-leeway-seconds` — DPoP proof time leeway (default: 30)

**User Claims (via `Auth0AuthenticationToken`):**
- `authentication.getName()` — User ID (subject / `sub` claim)
- `token.getClaim("email")` — Any specific claim by name
- `token.getClaims()` — All JWT claims as `Map<String, Object>`
- `token.getScopes()` — Scopes as `Set<String>`

**Common Use Cases:**
- Protect routes → `requestMatchers("/path").authenticated()` (see Step 4)
- Scope enforcement → `hasAuthority("SCOPE_read:data")` or `@PreAuthorize` (see [Integration Guide](references/integration.md))
- DPoP token binding → [Integration Guide](references/integration.md)
- Complete API reference → [API Reference](references/api.md)

---

## Detailed Documentation

- **[Setup Guide](references/setup.md)** — Auth0 CLI automation, environment configuration, secret management
- **[Integration Guide](references/integration.md)** — Scope policies, DPoP, controller patterns, error handling
- **[API Reference](references/api.md)** — Complete configuration options, claims reference, testing checklist

---

## References

- [Auth0 Java Spring Security API Quickstart](https://auth0.com/docs/quickstart/backend/java-spring-security5)
- [SDK GitHub Repository](https://github.com/auth0/auth0-auth-java)
- [Spring Security Documentation](https://docs.spring.io/spring-security/reference/)
- [Access Tokens Guide](https://auth0.com/docs/secure/tokens/access-tokens)
- [DPoP RFC 9449](https://datatracker.ietf.org/doc/html/rfc9449)
