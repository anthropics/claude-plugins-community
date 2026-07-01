# Go JWT Middleware Integration Patterns

Advanced integration patterns for Go API applications using go-jwt-middleware v3.

---

## Permission-Based Authorization

### Define Custom Claims

```go
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

func (c CustomClaims) HasPermission(expectedPermission string) bool {
	for _, p := range c.Permissions {
		if p == expectedPermission {
			return true
		}
	}
	return false
}
```

### Register Custom Claims with Validator

```go
jwtValidator, err := validator.New(
	validator.WithKeyFunc(provider.KeyFunc),
	validator.WithAlgorithm(validator.RS256),
	validator.WithIssuer(issuerURL.String()),
	validator.WithAudience(os.Getenv("AUTH0_AUDIENCE")),
	validator.WithCustomClaims(func() validator.CustomClaims {
		return &CustomClaims{}
	}),
)
```

### Check Permissions in Handlers

```go
func privateScopedHandler(w http.ResponseWriter, r *http.Request) {
	claims, err := jwtmiddleware.GetClaims[*validator.ValidatedClaims](r.Context())
	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		http.Error(w, `{"message":"Failed to get token claims."}`, http.StatusInternalServerError)
		return
	}

	customClaims := claims.CustomClaims.(*CustomClaims)
	if !customClaims.HasScope("read:messages") {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusForbidden)
		json.NewEncoder(w).Encode(map[string]string{"message": "Insufficient scope."})
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"message": "Hello from a scoped endpoint!"})
}
```

### Define Permissions in Auth0

1. Go to Auth0 Dashboard → Applications → APIs
2. Select your API
3. Click the **Permissions** tab
4. Add permissions matching your scope names (e.g., `read:messages`, `write:messages`)

### Request Tokens with Scopes

Clients must request tokens that include the required scopes:

```bash
curl -X POST https://your-tenant.auth0.com/oauth/token \
  -H "Content-Type: application/json" \
  -d '{
    "client_id": "YOUR_CLIENT_ID",
    "client_secret": "YOUR_CLIENT_SECRET",
    "audience": "https://my-api.example.com",
    "grant_type": "client_credentials",
    "scope": "read:messages write:messages"
  }'
```

---

## CORS Configuration

For APIs called from browser-based SPAs, configure CORS before the JWT middleware. CORS must handle preflight OPTIONS requests before auth:

```go
func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "http://localhost:3000")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type")
		w.Header().Set("Access-Control-Max-Age", "86400")

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusNoContent)
			return
		}

		next.ServeHTTP(w, r)
	})
}
```

Apply CORS before JWT middleware:

```go
mux := http.NewServeMux()
mux.HandleFunc("/api/public", publicHandler)
mux.Handle("/api/private", middleware.CheckJWT(http.HandlerFunc(privateHandler)))

// CORS wraps the entire mux — must be outermost
handler := corsMiddleware(mux)
log.Fatal(http.ListenAndServe(":8080", handler))
```

For production, replace the hardcoded origin with your SPA domain. Use the `rs/cors` package for more advanced CORS configuration:

```bash
go get github.com/rs/cors
```

```go
import "github.com/rs/cors"

c := cors.New(cors.Options{
	AllowedOrigins:   []string{"https://your-spa.example.com"},
	AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE"},
	AllowedHeaders:   []string{"Authorization", "Content-Type"},
	AllowCredentials: true,
})

handler := c.Handler(mux)
```

---

## DPoP Support

DPoP (Demonstrating Proof of Possession, RFC 9449) binds tokens to a specific client key pair, preventing token theft.

### Enable DPoP

```go
middleware, err := jwtmiddleware.New(
	jwtmiddleware.WithValidator(jwtValidator),
	jwtmiddleware.WithDPoPMode(jwtmiddleware.DPoPAllowed),
)
```

### DPoP Required Mode

To reject standard Bearer tokens and accept only DPoP-bound tokens:

```go
middleware, err := jwtmiddleware.New(
	jwtmiddleware.WithValidator(jwtValidator),
	jwtmiddleware.WithDPoPMode(jwtmiddleware.DPoPRequired),
)
```

### DPoP Modes

| Mode | Behavior |
|------|----------|
| `jwtmiddleware.DPoPDisabled` | Standard JWT Bearer only, DPoP disabled |
| `jwtmiddleware.DPoPAllowed` | Accept both DPoP-bound and standard Bearer tokens |
| `jwtmiddleware.DPoPRequired` | Only accept DPoP-bound tokens; reject standard Bearer |

### Trusted Proxy Configuration

For APIs behind a reverse proxy (e.g., nginx, AWS ALB):

```go
middleware, err := jwtmiddleware.New(
	jwtmiddleware.WithValidator(jwtValidator),
	jwtmiddleware.WithDPoPMode(jwtmiddleware.DPoPRequired),
	jwtmiddleware.WithStandardProxy(),
)
```

---

## Accessing Claims

### Type-Safe Claims Retrieval (v3)

```go
claims, err := jwtmiddleware.GetClaims[*validator.ValidatedClaims](r.Context())
if err != nil {
	http.Error(w, "Failed to get claims", http.StatusInternalServerError)
	return
}

userId := claims.RegisteredClaims.Subject
issuer := claims.RegisteredClaims.Issuer
customClaims := claims.CustomClaims.(*CustomClaims)
```

### Common JWT Claims

| Claim | Go Access Pattern | Description |
|-------|-------------------|-------------|
| `sub` | `claims.RegisteredClaims.Subject` | User ID (subject) |
| `iss` | `claims.RegisteredClaims.Issuer` | Token issuer (your Auth0 tenant URL) |
| `aud` | `claims.RegisteredClaims.Audience` | Audience (your API identifier) |
| `exp` | `claims.RegisteredClaims.Expiry` | Expiration timestamp |
| `iat` | `claims.RegisteredClaims.IssuedAt` | Issued-at timestamp |
| `scope` | `customClaims.Scope` | Space-separated list of granted scopes |
| `permissions` | `customClaims.Permissions` | Permission strings (RBAC) |

Custom claims added via Auth0 Actions use namespaced keys. Add them to your `CustomClaims` struct:

```go
type CustomClaims struct {
	Scope       string   `json:"scope"`
	Permissions []string `json:"permissions"`
	Email       string   `json:"https://your-domain.com/email"`
}
```

---

## Error Handling

### Custom Error Handler

```go
func customErrorHandler(w http.ResponseWriter, r *http.Request, err error) {
	w.Header().Set("Content-Type", "application/json")

	if errors.Is(err, jwtmiddleware.ErrJWTMissing) {
		w.WriteHeader(http.StatusUnauthorized)
		json.NewEncoder(w).Encode(map[string]string{
			"error":   "missing_token",
			"message": "Authorization header with Bearer token is required.",
		})
		return
	}

	w.WriteHeader(http.StatusUnauthorized)
	json.NewEncoder(w).Encode(map[string]string{
		"error":   "invalid_token",
		"message": "The provided token is invalid.",
	})
}

middleware, err := jwtmiddleware.New(
	jwtmiddleware.WithValidator(jwtValidator),
	jwtmiddleware.WithErrorHandler(customErrorHandler),
)
```

### Standard Error Responses

| Status | Cause | Fix |
|--------|-------|-----|
| 401 | Missing or invalid token | Include valid `Authorization: Bearer <token>` header |
| 401 | Expired token | Request a fresh access token |
| 401 | Wrong audience | Token's `aud` claim must match your API Identifier |
| 403 | Insufficient scope | Token must include required scopes/permissions |

---

## Mixed Public and Protected Endpoints

```go
mux := http.NewServeMux()

// Public - no auth needed
mux.HandleFunc("/api/public", publicHandler)

// Protected - requires valid JWT
mux.Handle("/api/private", middleware.CheckJWT(http.HandlerFunc(privateHandler)))

// Protected with scope - requires JWT + specific permission
mux.Handle("/api/private-scoped", middleware.CheckJWT(http.HandlerFunc(privateScopedHandler)))
```

---

## Optional Credentials Mode

Allow endpoints to work for both authenticated and unauthenticated users:

```go
middleware, err := jwtmiddleware.New(
	jwtmiddleware.WithValidator(jwtValidator),
	jwtmiddleware.WithCredentialsOptional(true),
)
```

In your handler, check if claims exist:

```go
func handler(w http.ResponseWriter, r *http.Request) {
	if jwtmiddleware.HasClaims(r.Context()) {
		claims, _ := jwtmiddleware.GetClaims[*validator.ValidatedClaims](r.Context())
		// Authenticated user
	} else {
		// Anonymous user
	}
}
```

---

## URL Exclusions

Skip JWT validation for specific paths:

```go
middleware, err := jwtmiddleware.New(
	jwtmiddleware.WithValidator(jwtValidator),
	jwtmiddleware.WithExclusionUrls([]string{"/health", "/metrics", "/api/public"}),
)
```

---

## Framework Adapters

### Gin

```go
import "github.com/gin-gonic/gin"

r := gin.Default()

r.GET("/api/public", func(c *gin.Context) {
	c.JSON(200, gin.H{"message": "public"})
})

r.GET("/api/private", gin.WrapH(middleware.CheckJWT(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
	claims, _ := jwtmiddleware.GetClaims[*validator.ValidatedClaims](r.Context())
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"userId": claims.RegisteredClaims.Subject})
}))))
```

### Echo

```go
import "github.com/labstack/echo/v4"

e := echo.New()

e.GET("/api/public", func(c echo.Context) error {
	return c.JSON(200, map[string]string{"message": "public"})
})

e.GET("/api/private", echo.WrapHandler(middleware.CheckJWT(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
	claims, _ := jwtmiddleware.GetClaims[*validator.ValidatedClaims](r.Context())
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"userId": claims.RegisteredClaims.Subject})
}))))
```

---

## Structured Logging

```go
import "log/slog"

middleware, err := jwtmiddleware.New(
	jwtmiddleware.WithValidator(jwtValidator),
	jwtmiddleware.WithLogger(slog.Default()),
)
```

---

## Custom Token Extraction

### From Cookie

```go
middleware, err := jwtmiddleware.New(
	jwtmiddleware.WithValidator(jwtValidator),
	jwtmiddleware.WithTokenExtractor(jwtmiddleware.CookieTokenExtractor("jwt")),
)
```

### From Query Parameter

```go
middleware, err := jwtmiddleware.New(
	jwtmiddleware.WithValidator(jwtValidator),
	jwtmiddleware.WithTokenExtractor(jwtmiddleware.ParameterTokenExtractor("token")),
)
```

### Multiple Sources

```go
middleware, err := jwtmiddleware.New(
	jwtmiddleware.WithValidator(jwtValidator),
	jwtmiddleware.WithTokenExtractor(jwtmiddleware.MultiTokenExtractor(
		jwtmiddleware.AuthHeaderTokenExtractor,
		jwtmiddleware.CookieTokenExtractor("jwt"),
	)),
)
```

---

## Testing

### Unit Testing with httptest

```go
func TestPublicEndpoint_Returns200(t *testing.T) {
	mux := setupRouter() // your function that sets up routes
	req := httptest.NewRequest("GET", "/api/public", nil)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
}

func TestPrivateEndpoint_WithoutToken_Returns401(t *testing.T) {
	mux := setupRouter()
	req := httptest.NewRequest("GET", "/api/private", nil)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", w.Code)
	}
}
```

### Testing with a Real Token

```bash
# Get a token via Auth0 CLI (uses client credentials for M2M apps)
TOKEN=$(auth0 test token <M2M_CLIENT_ID> --audience https://my-api.example.com --scopes "read:messages" --json | jq -r '.access_token')

# Test private endpoint
curl -H "Authorization: Bearer $TOKEN" http://localhost:8080/api/private
```

---

## Security Considerations

- **Never hardcode Domain or Audience** - Always use `.env` or environment variables
- **Use HTTPS in production** - Auth0 requires HTTPS for token validation
- **Use minimal scopes** - Only request and enforce scopes your API actually needs
- **Set appropriate clock skew** - Use `validator.WithAllowedClockSkew()` for distributed systems
- **Validate custom claims** - Implement the `Validate()` method on your custom claims struct
- **Use DPoP for high-security APIs** - Prevents token theft and replay attacks
- **Keep packages updated** - Run `go get -u github.com/auth0/go-jwt-middleware/v3` regularly

---

## References

- [API Reference](api.md)
- [Setup Guide](setup.md)
- [Main Skill](../SKILL.md)
