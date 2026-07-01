# Auth0 Spring Boot API Setup Guide

Setup instructions for Spring Boot API applications using `auth0-springboot-api`.

---

## Auth0 Configuration

> **Agent instruction:**
>
> **Check if Auth0 domain and audience are already in the user's prompt first.**
> If the prompt contains Auth0 domain and audience, use them directly — skip to "Write Configuration" below. Do NOT call `AskUserQuestion` to re-confirm.
>
> **If Auth0 configuration is NOT provided**, use `AskUserQuestion` to ask:
> "How would you like to configure Auth0?"
> - Option A: "Automatic setup using Auth0 CLI (recommended)"
> - Option B: "Manual setup" — provide domain and audience manually
>
> **If Automatic Setup:**
>
> 1. **Pre-flight checks:**
>    - Verify Auth0 CLI is installed: `auth0 --version`
>    - Verify logged in: `auth0 tenants list --csv --no-input`
>    - If any check fails, guide user to install/login, or fall back to manual setup
>
> 2. **Create the API resource using Auth0 CLI:**
>    ```bash
>    auth0 apis create --name "My Spring Boot API" --identifier https://my-springboot-api --json
>    ```
>    Then write the returned domain and audience to `application.yml`.
>
> **If Manual Setup:**
>
> Ask the user for:
> - Auth0 Domain (e.g., `your-tenant.auth0.com`)
> - API Audience / Identifier (e.g., `https://my-springboot-api`)
>
> Write the configuration file with provided values.

---

## Quick Setup (Automated)

Uses the Auth0 CLI to create an Auth0 API resource and configure your project.

### Step 1: Install Auth0 CLI and create API resource

```bash
# Install Auth0 CLI (macOS)
brew install auth0/auth0-cli/auth0

# Login
auth0 login --no-input

# Create an Auth0 API resource
auth0 apis create \
  --name "My Spring Boot API" \
  --identifier https://my-springboot-api \
  --json
```

Note the `identifier` value — this is your Audience.

### Step 2: Get your domain

```bash
auth0 tenants list
```

Your domain is shown in the output (e.g., `your-tenant.auth0.com`).

### Step 3: Write configuration

Add to `src/main/resources/application.yml`:

```yaml
auth0:
  domain: "your-tenant.auth0.com"
  audience: "https://my-springboot-api"
```

Or `src/main/resources/application.properties`:

```properties
auth0.domain=your-tenant.auth0.com
auth0.audience=https://my-springboot-api
```

---

## Manual Setup

### Install Dependency

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

### Create Auth0 API Resource

1. Go to Auth0 Dashboard → Applications → APIs
2. Click **Create API**
3. Set a **Name** and an **Identifier** (e.g., `https://my-springboot-api`)
4. Note the Identifier — this is your `audience`

### Configure application.yml

```yaml
auth0:
  domain: "your-tenant.auth0.com"
  audience: "https://my-springboot-api"
```

**Important:** Domain format is `your-tenant.auth0.com` — do NOT include `https://`.

### Get Auth0 Configuration

- **Domain:** Auth0 Dashboard → Settings → Domain (or `auth0 tenants list`)
- **Audience:** The identifier you set when creating the API resource

---

## Post-Setup Steps

1. **Verify audience matches** — The `auth0.audience` value must exactly match your API Identifier in Auth0 Dashboard
2. **Add SecurityConfig** — Create a `SecurityConfig.java` class with `Auth0AuthenticationFilter` added before `UsernamePasswordAuthenticationFilter`
3. **Build and test** — Run `./gradlew bootRun` (or `./mvnw spring-boot:run`) and test endpoints

---

## Environment-Specific Configuration

This library validates JWTs via JWKS (public key verification). **No client secret is needed.**

The `domain` and `audience` values are not secrets — they are public identifiers. However, they typically differ per environment:

### Development

Use `application.yml` or `application.properties` directly:

```yaml
auth0:
  domain: "your-tenant.auth0.com"
  audience: "https://my-springboot-api"
```

### Production

Use environment variables (override `application.yml`):

```bash
export AUTH0_DOMAIN=your-tenant.auth0.com
export AUTH0_AUDIENCE=https://my-springboot-api
```

Or use Spring profiles (`application-prod.yml`).

---

## Getting a Test Token

### Via Auth0 Dashboard

1. Go to Auth0 Dashboard → Applications → APIs
2. Select your API
3. Click the **Test** tab
4. Click **Copy Token** to get a test access token

### Via Auth0 CLI (Client Credentials)

```bash
auth0 test token \
  --audience https://my-springboot-api
```

### Via curl (Client Credentials Flow)

```bash
curl -X POST https://your-tenant.auth0.com/oauth/token \
  -H "Content-Type: application/json" \
  -d '{
    "client_id": "YOUR_CLIENT_ID",
    "client_secret": "YOUR_CLIENT_SECRET",
    "audience": "https://my-springboot-api",
    "grant_type": "client_credentials"
  }'
```

---

## Verification

1. Application starts without errors: `./gradlew bootRun`
2. Public endpoint accessible without token: `curl http://localhost:8080/api/public`
3. Protected endpoint returns 401 without token: `curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/protected`
4. Protected endpoint returns 200 with valid token

---

## Troubleshooting

**401 Unauthorized - "invalid_token":** Verify that the `auth0.audience` in config exactly matches your API Identifier in Auth0 Dashboard.

**401 Unauthorized - "invalid_issuer":** Ensure `auth0.domain` does not include `https://` — use `your-tenant.auth0.com` format only.

**No Auth0AuthenticationFilter bean found:** Ensure `auth0-springboot-api` dependency is on the classpath and both `auth0.domain` and `auth0.audience` are configured.

**Token expired:** Test tokens from the Dashboard are short-lived. Request a fresh token.

---

## Next Steps

- [Integration Guide](integration.md)
- [API Reference](api.md)
- [Main Skill](../SKILL.md)
