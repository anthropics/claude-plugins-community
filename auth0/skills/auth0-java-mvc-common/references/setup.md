# Auth0 Java MVC Common Setup Guide

Setup and configuration guide for Auth0 Java Servlet authentication using `com.auth0:mvc-auth-commons`.

---

## Auth0 Configuration

> **Agent instruction:** Do not write or echo credential values yourself. If the user's prompt already provides Auth0 credentials (domain, client ID, client secret), skip the credential questions and instruct the user to populate their `.env` file — provide variable names and placeholders (`<YOUR_DOMAIN>`, `<YOUR_CLIENT_ID>`, `<YOUR_CLIENT_SECRET>`), never actual values.
>
> **Secret handling:** Never retrieve or parse `client_secret` from Auth0 CLI output. Never write actual credential values into any file — always use placeholders. Do NOT read `.env` files. Always add `.env` to `.gitignore` if not already present. Warn the user to check for duplicates if they may have already configured credentials.

### Option A: Automatic Setup (Auth0 CLI)

> **Agent instruction:** Use Auth0 CLI to handle Auth0 configuration automatically:
> 1. **Pre-flight checks:**
>    - Verify Auth0 CLI is installed: `auth0 --version`
>    - Verify logged in: `auth0 tenants list --csv --no-input`
>    - If any check fails, guide user to install/login, or fall back to manual setup
>
> 2. **Create the application using Auth0 CLI:**
>    ```bash
>    auth0 apps create --name "My Java Web App" --type regular --callbacks http://localhost:3000/callback --logout-urls http://localhost:3000 --json --no-input
>    ```
>    From the JSON output, note the `domain` and `client_id`. Instruct the user to add these values (along with `client_secret`) to their `.env` file themselves.
>    Do NOT extract or write any credential values from the CLI output.

### Option B: Manual Setup

> **Agent instruction:** If the user chose manual setup, use `AskUserQuestion` to collect:
> 1. Auth0 Domain
> 2. Client ID
> 3. Client Secret
>
> Then instruct the user to add these values to their `.env` file. Do not write credential values yourself — provide the template with placeholders only.

#### 1. Create Auth0 Application

```bash
# Using Auth0 CLI
auth0 apps create \
  --name "My Java Web App" \
  --type regular \
  --callbacks http://localhost:3000/callback \
  --logout-urls http://localhost:3000 \
  --json
```

Or manually in Auth0 Dashboard:
1. Go to Applications → Applications → Create Application
2. Select **Regular Web Applications**
3. Note the **Domain**, **Client ID**, and **Client Secret**
4. Under Settings → Application URIs:
   - Allowed Callback URLs: `http://localhost:3000/callback`
   - Allowed Logout URLs: `http://localhost:3000`

#### 2. Set Up Database Connection

```bash
# List existing connections
auth0 connections list --json

# Enable your app on the default database connection
# (done automatically if using Option A: Automatic Setup)
```

#### 3. Write Environment Configuration

Create a `.env` file in your project root (add to `.gitignore`):

```properties
AUTH0_DOMAIN=your-tenant.auth0.com
AUTH0_CLIENT_ID=your-client-id
AUTH0_CLIENT_SECRET=your-client-secret
```


> **Agent instruction:** Never write actual credential values to files. Instruct the user to populate `.env` with their credentials. If `.env` already exists, remind the user to append (not overwrite). Always add `.env` to `.gitignore` automatically.

> **Agent instruction:** Java does not auto-load `.env` files. If you generate a `.env` file, also add [dotenv-java](https://github.com/cdimascio/dotenv-java) and use `Dotenv.load().get("AUTH0_DOMAIN")`, or instruct the user to run `source .env` before starting the server.

---

## Secret Management

### Development

Use a `.env` file in the project root:

```properties
AUTH0_DOMAIN=your-tenant.auth0.com
AUTH0_CLIENT_ID=your-client-id
AUTH0_CLIENT_SECRET=your-client-secret
```

> **Agent instruction:** Never write actual credential values to files. Instruct the user to populate `.env` with their own values. Never retrieve secrets from CLI output. Always ensure `.env` is in `.gitignore`.

**Important:** Add `.env` to `.gitignore` to prevent committing secrets:

```bash
echo ".env" >> .gitignore
```

Load environment variables in your application. For servlet containers:

**Option 1: System environment variables**

Set on the system or in the container startup script:

```bash
export AUTH0_DOMAIN="your-tenant.auth0.com"
export AUTH0_CLIENT_ID="your-client-id"
export AUTH0_CLIENT_SECRET="your-client-secret"
```

**Option 2: Servlet context parameters (web.xml)**

```xml
<context-param>
    <param-name>auth0.domain</param-name>
    <param-value>${AUTH0_DOMAIN}</param-value>
</context-param>
```

Read in code:

```java
String domain = getServletContext().getInitParameter("auth0.domain");
```

### Production

Use your deployment platform's secret management:

| Platform | Method |
|----------|--------|
| Docker | `docker run -e AUTH0_DOMAIN=... -e AUTH0_CLIENT_ID=...` |
| Kubernetes | Secrets mounted as env vars |
| AWS | Parameter Store or Secrets Manager |
| Heroku | `heroku config:set AUTH0_DOMAIN=...` |
| Tomcat | Set in `setenv.sh` or JNDI context |

**Never commit secrets to source control.**

---

## Dependency Installation

### Gradle (build.gradle)

```groovy
dependencies {
    implementation 'com.auth0:mvc-auth-commons:1.12.0'
}
```

### Maven (pom.xml)

```xml
<dependency>
    <groupId>com.auth0</groupId>
    <artifactId>mvc-auth-commons</artifactId>
    <version>1.12.0</version>
</dependency>
```

### Verify Installation

```bash
# Gradle
./gradlew dependencies | grep mvc-auth-commons

# Maven
mvn dependency:tree | grep mvc-auth-commons
```

---

## Project Structure

Typical Java Servlet project with Auth0:

```text
src/main/java/
├── com/example/
│   ├── Auth0Config.java          # AuthenticationController singleton
│   ├── LoginServlet.java         # /login endpoint
│   ├── CallbackServlet.java      # /callback endpoint
│   ├── LogoutServlet.java        # /logout endpoint
│   ├── AuthenticationFilter.java # Protect routes
│   └── DashboardServlet.java     # Protected page
src/main/webapp/
├── WEB-INF/
│   └── web.xml                   # Servlet configuration
.env                              # Auth0 credentials (gitignored)
```

---

## Callback URL Configuration

The callback URL must match **exactly** between your code and Auth0 Dashboard.

| Environment | Callback URL |
|-------------|-------------|
| Development | `http://localhost:3000/callback` |
| Production | `https://yourdomain.com/callback` |

**Build callback URL dynamically in the Login servlet:**

```java
String scheme = request.getScheme();
int port = request.getServerPort();
String redirectUrl = scheme + "://" + request.getServerName()
    + ((port == 80 || port == 443) ? "" : ":" + port) + "/callback";
```

---

## Troubleshooting

| Problem | Cause | Solution |
|---------|-------|----------|
| `ClassNotFoundException: com.auth0.AuthenticationController` | Dependency not in classpath | Verify Maven/Gradle dependency and rebuild |
| Auth0 returns "Callback URL mismatch" | URL in code ≠ Dashboard | Copy exact URL from code to Allowed Callback URLs |
| `IdentityVerificationException: a0.invalid_jwt_error` | Clock skew | Add `.withClockSkew(300)` to builder |
| Login redirects but callback fails silently | Missing session cookie across redirects | Check cookie SameSite settings and domain |
| `NullPointerException` reading env vars | Environment variables not set | Verify `.env` is loaded or vars are exported |

---

## References

- [API Reference](api.md)
- [Integration Guide](integration.md)
- [Main Skill](../SKILL.md)
