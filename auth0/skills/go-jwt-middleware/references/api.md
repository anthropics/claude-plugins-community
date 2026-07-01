# Go JWT Middleware API Reference

Complete reference for github.com/auth0/go-jwt-middleware/v3 configuration options.

---

## Validator Options

Create a validator with `validator.New()` using functional options:

```go
jwtValidator, err := validator.New(
	validator.WithKeyFunc(provider.KeyFunc),
	validator.WithAlgorithm(validator.RS256),
	validator.WithIssuer(issuerURL.String()),
	validator.WithAudience(os.Getenv("AUTH0_AUDIENCE")),
)
```

| Option | Type | Required | Description |
|--------|------|----------|-------------|
| `validator.WithKeyFunc(fn)` | `func(context.Context) (any, error)` | Yes | Key function for signature verification. Use `provider.KeyFunc` from JWKS provider. |
| `validator.WithAlgorithm(alg)` | `validator.Algorithm` | Yes | Expected signing algorithm. Use `validator.RS256` for Auth0. |
| `validator.WithIssuer(url)` | `string` | Yes | Token issuer URL. Must be `https://{domain}/` with trailing slash. |
| `validator.WithAudience(aud)` | `string` | Yes | Expected audience. Must match API Identifier in Auth0 Dashboard. |
| `validator.WithCustomClaims(fn)` | `func() validator.CustomClaims` | No | Factory function returning a custom claims struct. |
| `validator.WithAllowedClockSkew(d)` | `time.Duration` | No | Clock skew tolerance for token expiration. Default: 0. |

---

## Middleware Options

Create middleware with `jwtmiddleware.New()` using functional options:

```go
middleware, err := jwtmiddleware.New(
	jwtmiddleware.WithValidator(jwtValidator),
)
```

| Option | Type | Description |
|--------|------|-------------|
| `jwtmiddleware.WithValidator(v)` | `core.Validator` | JWT validator instance (required) |
| `jwtmiddleware.WithErrorHandler(fn)` | `func(http.ResponseWriter, *http.Request, error)` | Custom error response handler |
| `jwtmiddleware.WithCredentialsOptional(b)` | `bool` | Allow requests without tokens (default: false) |
| `jwtmiddleware.WithTokenExtractor(fn)` | `jwtmiddleware.TokenExtractor` | Custom token extraction from request |
| `jwtmiddleware.WithExclusionUrls(urls)` | `[]string` | URL paths to skip JWT validation |
| `jwtmiddleware.WithLogger(l)` | `*slog.Logger` | Structured logger for validation events |
| `jwtmiddleware.WithDPoPMode(mode)` | `jwtmiddleware.DPoPMode` | DPoP proof-of-possession mode |
| `jwtmiddleware.WithStandardProxy()` | - | Trust X-Forwarded-* headers for DPoP behind reverse proxies |

---

## JWKS Provider Options

Create a caching JWKS provider with `jwks.NewCachingProvider()`:

```go
provider, err := jwks.NewCachingProvider(
	jwks.WithIssuerURL(issuerURL),
)
```

| Option | Type | Description |
|--------|------|-------------|
| `jwks.WithIssuerURL(url)` | `*url.URL` | Auth0 issuer URL. Fetches JWKS from `{url}.well-known/jwks.json`. |

---

## Claims Reference

### Registered Claims

Access via `claims.RegisteredClaims`:

| Field | Type | Description |
|-------|------|-------------|
| `Subject` | `string` | User ID (`sub` claim) |
| `Issuer` | `string` | Token issuer (`iss` claim) |
| `Audience` | `[]string` | Audience list (`aud` claim) |
| `Expiry` | `*time.Time` | Expiration time (`exp` claim) |
| `IssuedAt` | `*time.Time` | Issue time (`iat` claim) |

### Custom Claims

Access via `claims.CustomClaims.(*YourType)`:

```go
claims, err := jwtmiddleware.GetClaims[*validator.ValidatedClaims](r.Context())
if err != nil {
	// handle error
}

// Registered claims
userId := claims.RegisteredClaims.Subject

// Custom claims (requires CustomClaims registered with validator)
customClaims := claims.CustomClaims.(*CustomClaims)
scope := customClaims.Scope
permissions := customClaims.Permissions
```

---

## DPoP Modes

| Mode | Value | Behavior |
|------|-------|----------|
| Disabled | `jwtmiddleware.DPoPDisabled` | Standard JWT Bearer only (default) |
| Allowed | `jwtmiddleware.DPoPAllowed` | Accept both DPoP-bound and standard Bearer tokens |
| Required | `jwtmiddleware.DPoPRequired` | Only accept DPoP-bound tokens; reject standard Bearer |

---

## Token Extractors

| Extractor | Usage | Description |
|-----------|-------|-------------|
| Default (Header) | Automatic | Extracts from `Authorization: Bearer <token>` |
| Cookie | `jwtmiddleware.CookieTokenExtractor("name")` | Extracts from named cookie |
| Parameter | `jwtmiddleware.ParameterTokenExtractor("param")` | Extracts from URL query parameter |
| Multi | `jwtmiddleware.MultiTokenExtractor(e1, e2, ...)` | Tries multiple extractors in order |

---

## Supported Algorithms

| Family | Algorithms |
|--------|-----------|
| HMAC | `HS256`, `HS384`, `HS512` |
| RSA | `RS256`, `RS384`, `RS512` |
| RSA-PSS | `PS256`, `PS384`, `PS512` |
| ECDSA | `ES256`, `ES384`, `ES512`, `ES256K` |
| EdDSA | `EdDSA` |

Auth0 uses **RS256** by default. Always use `validator.RS256` for Auth0 JWKS validation.

---

## Complete Code Example

```go
package main

import (
	"context"
	"encoding/json"
	"errors"
	"log"
	"log/slog"
	"net/http"
	"net/url"
	"os"
	"strings"

	jwtmiddleware "github.com/auth0/go-jwt-middleware/v3"
	"github.com/auth0/go-jwt-middleware/v3/jwks"
	"github.com/auth0/go-jwt-middleware/v3/validator"
	"github.com/joho/godotenv"
)

type CustomClaims struct {
	Scope       string   `json:"scope"`
	Permissions []string `json:"permissions"`
}

func (c CustomClaims) Validate(ctx context.Context) error {
	return nil
}

func (c CustomClaims) HasScope(expectedScope string) bool {
	for _, scope := range strings.Split(c.Scope, " ") {
		if scope == expectedScope {
			return true
		}
	}
	return false
}

func main() {
	if err := godotenv.Load(); err != nil {
		log.Fatalf("Error loading .env file: %v", err)
	}

	issuerURL, err := url.Parse("https://" + os.Getenv("AUTH0_DOMAIN") + "/")
	if err != nil {
		log.Fatalf("Failed to parse issuer URL: %v", err)
	}

	provider, err := jwks.NewCachingProvider(
		jwks.WithIssuerURL(issuerURL),
	)
	if err != nil {
		log.Fatalf("Failed to set up JWKS provider: %v", err)
	}

	jwtValidator, err := validator.New(
		validator.WithKeyFunc(provider.KeyFunc),
		validator.WithAlgorithm(validator.RS256),
		validator.WithIssuer(issuerURL.String()),
		validator.WithAudience(os.Getenv("AUTH0_AUDIENCE")),
		validator.WithCustomClaims(func() validator.CustomClaims {
			return &CustomClaims{}
		}),
	)
	if err != nil {
		log.Fatalf("Failed to set up JWT validator: %v", err)
	}

	middleware, err := jwtmiddleware.New(
		jwtmiddleware.WithValidator(jwtValidator),
		jwtmiddleware.WithErrorHandler(func(w http.ResponseWriter, r *http.Request, err error) {
			w.Header().Set("Content-Type", "application/json")
			if errors.Is(err, jwtmiddleware.ErrJWTMissing) {
				w.WriteHeader(http.StatusUnauthorized)
				json.NewEncoder(w).Encode(map[string]string{"message": "Missing authorization token."})
				return
			}
			w.WriteHeader(http.StatusUnauthorized)
			json.NewEncoder(w).Encode(map[string]string{"message": "Invalid token."})
		}),
		jwtmiddleware.WithLogger(slog.Default()),
	)
	if err != nil {
		log.Fatalf("Failed to set up JWT middleware: %v", err)
	}

	mux := http.NewServeMux()

	mux.HandleFunc("/api/public", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"message": "Hello from a public endpoint!"})
	})

	mux.Handle("/api/private", middleware.CheckJWT(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		claims, _ := jwtmiddleware.GetClaims[*validator.ValidatedClaims](r.Context())
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{
			"message": "Hello from a private endpoint!",
			"userId":  claims.RegisteredClaims.Subject,
		})
	})))

	mux.Handle("/api/private-scoped", middleware.CheckJWT(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		claims, _ := jwtmiddleware.GetClaims[*validator.ValidatedClaims](r.Context())
		customClaims := claims.CustomClaims.(*CustomClaims)
		if !customClaims.HasScope("read:messages") {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusForbidden)
			json.NewEncoder(w).Encode(map[string]string{"message": "Insufficient scope."})
			return
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"message": "Hello from a scoped endpoint!"})
	})))

	server := &http.Server{
		Addr:    ":8080",
		Handler: mux,
	}

	log.Println("Server listening on :8080")
	log.Fatal(server.ListenAndServe())
}
```

---

## Testing Checklist

| Test | Command | Expected |
|------|---------|----------|
| Public endpoint | `curl http://localhost:8080/api/public` | 200 with message |
| Private without token | `curl http://localhost:8080/api/private` | 401 |
| Private with token | `curl -H "Authorization: Bearer TOKEN" http://localhost:8080/api/private` | 200 with userId |
| Scoped with token | `curl -H "Authorization: Bearer TOKEN" http://localhost:8080/api/private-scoped` | 200 (with scope) or 403 |
| Invalid token | `curl -H "Authorization: Bearer invalid" http://localhost:8080/api/private` | 401 |

---

## Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| 401 on all requests | Wrong issuer URL | Ensure trailing slash: `https://domain/` |
| 401 invalid_token | Audience mismatch | `AUTH0_AUDIENCE` must exactly match API identifier |
| panic: nil pointer | Missing error check | Always check `err` from `New()` functions |
| JWKS fetch fails | Network/firewall | Check connectivity to `https://domain/.well-known/jwks.json` |
| Claims type assertion fails | Wrong type parameter | Use `GetClaims[*validator.ValidatedClaims]`, not `ValidatedClaims` |
| v2 code doesn't compile | Breaking API changes | See [Migration Guide](https://github.com/auth0/go-jwt-middleware/blob/master/MIGRATION_GUIDE.md) |

---

## Security Considerations

- **Never hardcode Domain or Audience** - Use `.env` for development, environment variables for production
- **Use HTTPS in production** - Auth0 requires HTTPS for secure token validation
- **Use minimal scopes** - Only request and enforce scopes your API actually needs
- **Keep packages updated** - Run `go get -u github.com/auth0/go-jwt-middleware/v3` for security patches
- **Set appropriate clock skew** - Use `validator.WithAllowedClockSkew()` in distributed environments
- **Validate custom claims** - Implement non-trivial `Validate()` logic when business rules require it

---

## References

- [Auth0 Go API Quickstart](https://auth0.com/docs/quickstart/backend/golang/interactive)
- [SDK GitHub Repository](https://github.com/auth0/go-jwt-middleware)
- [Go Package Documentation](https://pkg.go.dev/github.com/auth0/go-jwt-middleware/v3)
- [Migration Guide (v2 to v3)](https://github.com/auth0/go-jwt-middleware/blob/master/MIGRATION_GUIDE.md)
