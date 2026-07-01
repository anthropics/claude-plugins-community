# Auth0 CLI Reference

Complete guide to installing, configuring, and using the Auth0 CLI.

---

## Installation

### macOS/Linux

**Via Homebrew (recommended):**
```bash
brew install auth0/auth0-cli/auth0
```

**Via curl (review script before executing):**
```bash
curl -sSfL https://raw.githubusercontent.com/auth0/auth0-cli/main/install.sh -o /tmp/auth0-install.sh
# Review the script before running: cat /tmp/auth0-install.sh
sh /tmp/auth0-install.sh
rm /tmp/auth0-install.sh
```

### Windows

**Via Scoop:**
```bash
scoop install auth0
```

**Via Chocolatey:**
```bash
choco install auth0-cli
```

### Verify Installation

```bash
auth0 --version
which auth0
```

---

## Initial Setup

### Login to Auth0

```bash
auth0 login
```

This opens your browser to authenticate with Auth0.

### Check Current Tenant

```bash
# List all tenants
auth0 tenants list

# Show current tenant
auth0 tenants use
```

---

## Creating Applications

### Single Page Application (SPA)

For React, Vue, Angular applications:

```bash
auth0 apps create \
  --name "My React App" \
  --type spa \
  --callbacks "http://localhost:3000" \
  --logout-urls "http://localhost:3000" \
  --origins "http://localhost:3000" \
  --web-origins "http://localhost:3000" \
  --metadata "created_by=agent_skills"
```

### Regular Web Application

For Next.js, Express, server-rendered applications:

```bash
auth0 apps create \
  --name "My Next.js App" \
  --type regular \
  --callbacks "http://localhost:3000/api/auth/callback" \
  --logout-urls "http://localhost:3000" \
  --metadata "created_by=agent_skills"
```

### Native Application

For React Native, iOS, Android, mobile applications:

```bash
auth0 apps create \
  --name "My Mobile App" \
  --type native \
  --callbacks "myapp://callback" \
  --logout-urls "myapp://logout" \
  --metadata "created_by=agent_skills"
```

### Machine-to-Machine (M2M)

For backend APIs, cron jobs, server-to-server:

```bash
auth0 apps create \
  --name "My API Service" \
  --type m2m \
  --metadata "created_by=agent_skills"
```

---

## Managing Applications

### List Applications

```bash
# List all applications
auth0 apps list
```

### Show Application Details

```bash
# Show app details (includes client ID and secret)
auth0 apps show <app-id>
```

### Update Application

```bash
# Update callbacks
auth0 apps update <app-id> \
  --callbacks "http://localhost:3000,https://myapp.com"

# Update logout URLs
auth0 apps update <app-id> \
  --logout-urls "http://localhost:3000,https://myapp.com"
```

### Delete Application

```bash
auth0 apps delete <app-id>
```

---

## User Management

### List Users

```bash
# List all users
auth0 users list

# List with search
auth0 users search --query "email:*@example.com"
```

### Create User

```bash
auth0 users create \
  --email "user@example.com" \
  --password "SecurePassword123!" \
  --connection "Username-Password-Authentication"
```

### Show User Details

```bash
auth0 users show <user-id>
```

### Delete User

```bash
auth0 users delete <user-id>
```

---

## Testing & Debugging

### Test Login Flow

```bash
# Test login with Universal Login
auth0 test login <app-client-id>
```

### Get Access Token

```bash
# Get access token for testing APIs
auth0 test token <app-client-id>
```

### Live Log Streaming

```bash
# Tail Auth0 logs in real-time
auth0 logs tail

# Filter by type
auth0 logs tail --filter "type:f"  # Failed logins
auth0 logs tail --filter "type:s"  # Successful logins
```

---

## API Management

### List APIs

```bash
auth0 apis list
```

### Create API

```bash
auth0 apis create \
  --name "My API" \
  --identifier "https://api.myapp.com"
```

### Show API Details

```bash
auth0 apis show <api-id>
```

---

## Command Quick Reference

### Account & Tenant

| Command | Purpose |
|---------|---------|
| `auth0 login` | Login to Auth0 |
| `auth0 logout` | Logout from Auth0 |
| `auth0 tenants list` | List your Auth0 tenants |
| `auth0 tenants use <tenant>` | Switch to a different tenant |

### Applications

| Command | Purpose |
|---------|---------|
| `auth0 apps list` | List all applications |
| `auth0 apps show <id>` | Show application details (get credentials) |
| `auth0 apps create` | Create a new application |
| `auth0 apps update <id>` | Update application settings |
| `auth0 apps delete <id>` | Delete application |
| `auth0 apps open <id>` | Open application in dashboard |

### Users

| Command | Purpose |
|---------|---------|
| `auth0 users list` | List users in tenant |
| `auth0 users show <id>` | Show user details |
| `auth0 users create` | Create a new user |
| `auth0 users delete <id>` | Delete user |
| `auth0 users search` | Search users by query |
| `auth0 users open <id>` | Open user in dashboard |

### APIs

| Command | Purpose |
|---------|---------|
| `auth0 apis list` | List all APIs |
| `auth0 apis show <id>` | Show API details |
| `auth0 apis create` | Create a new API |
| `auth0 apis delete <id>` | Delete API |
| `auth0 apis open <id>` | Open API in dashboard |

### Testing & Debugging

| Command | Purpose |
|---------|---------|
| `auth0 test login <client-id>` | Test login flow |
| `auth0 test token <client-id>` | Get access token for testing |
| `auth0 logs tail` | Live tail of Auth0 logs |
| `auth0 logs list` | List recent log entries |

### Utility

| Command | Purpose |
|---------|---------|
| `auth0 --version` | Show CLI version |
| `auth0 <command> --help` | Show help for any command |
| `auth0 completion` | Generate shell completion |

---

## Common Flags

### Global Flags

- `--json` - Output as JSON
- `--format <format>` - Output format (json, yaml, csv)
- `--tenant <tenant>` - Specify tenant
- `--debug` - Enable debug logging
- `--no-color` - Disable colored output

### Examples

```bash
# Get JSON output
auth0 apps list --json

# Use specific tenant
auth0 apps list --tenant my-tenant

# Debug mode
auth0 apps create --debug --name "My App" --type spa --auth-method None
```

---

## References

- [Auth0 CLI GitHub](https://github.com/auth0/auth0-cli)
- [Auth0 CLI Documentation](https://auth0.github.io/auth0-cli/)
- [Auth0 Management API](https://auth0.com/docs/api/management/v2)
