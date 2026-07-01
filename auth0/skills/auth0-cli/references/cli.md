# Auth0 CLI — Full Command Reference

Detailed flags, examples, and usage patterns for every Auth0 CLI command. All examples use `--json` or `--json-compact` output format for machine-readable results.

---

## Table of Contents

- [Authentication](#authentication)
- [Apps](#apps)
- [APIs](#apis)
- [Users](#users)
- [Roles](#roles)
- [Organizations](#organizations)
- [Actions](#actions)
- [Logs](#logs)
- [Domains](#domains)
- [Universal Login](#universal-login)
- [Terraform](#terraform)
- [Test](#test)
- [Quickstarts](#quickstarts)
- [Attack Protection](#attack-protection)
- [Log Streams](#log-streams)
- [IPs](#ips)
- [Raw API Mode](#raw-api-mode)
- [Output Formatting](#output-formatting)
- [Shared Flags](#shared-flags)

---

## Authentication

Every CLI session requires an active login.

```bash
# Interactive device-code login (default for personal use)
auth0 login

# Request extra Management API scopes (needed if commands fail with 403)
auth0 login --scopes "read:client_grants,create:client_grants"

# Machine login with client secret (CI/CD, non-interactive)
auth0 login --domain <tenant>.auth0.com --client-id <id> --client-secret "$AUTH0_CLIENT_SECRET"

# Machine login with private key JWT
auth0 login --domain <tenant>.auth0.com --client-id <id> \
  --client-assertion-signing-alg RS256 \
  --client-assertion-private-key <key-or-path>
```

| Flag | Description |
|------|-------------|
| `--domain` | Tenant domain (required for machine login) |
| `--client-id` | Application client ID (for machine login) |
| `--client-secret` | Application client secret (for secret-based machine login) |
| `--client-assertion-signing-alg` | Signing algorithm: RS256, RS384, PS256 (for JWT machine login) |
| `--client-assertion-private-key` | Private key content or file path (for JWT machine login) |
| `--scopes` | Additional Management API scopes to request during user login |

Three authentication modes:
1. **User login** (device code flow) — no credentials needed, opens browser. Default for personal machines.
2. **Machine login with secret** — requires `--domain`, `--client-id`, `--client-secret`. For CI/CD.
3. **Machine login with JWT** — requires `--domain`, `--client-id`, `--client-assertion-signing-alg`, `--client-assertion-private-key`. For Private Cloud or high-security environments.

Always run `auth0 login` at the start of any workflow. If commands later fail with 403/insufficient scope, re-login with `--scopes` to add the missing scope.

### Tenant management

```bash
auth0 tenants list        # list all authenticated tenants
auth0 tenants use         # switch active tenant (interactive)
auth0 tenants open        # open tenant settings in browser
```

### Logout

```bash
auth0 logout              # interactive tenant selection
auth0 logout <tenant>     # logout specific tenant
```

---

## Apps

Manage Auth0 applications — the entity that holds your client ID, client secret, callback URLs, and app type.

**Alias:** `auth0 clients`

### apps list

```bash
auth0 apps list --json
auth0 apps list --reveal-secrets --number 100 --json-compact
```

| Flag | Short | Default | Description |
|------|-------|---------|-------------|
| `--number` | `-n` | 100 | Number of apps to retrieve (1–1000) |
| `--reveal-secrets` | `-r` | false | Show client secret and signing keys in output |
| `--json` | | false | JSON output |
| `--json-compact` | | false | Compact JSON output |
| `--csv` | | false | CSV output |

### apps show

```bash
auth0 apps show <client-id> --json
auth0 apps show <client-id> --reveal-secrets --json-compact
```

| Flag | Short | Description |
|------|-------|-------------|
| `--reveal-secrets` | `-r` | Show client secret and signing keys |
| `--json` | | JSON output |
| `--json-compact` | | Compact JSON output |

### apps create

```bash
# SPA (React, Vue, Angular — browser-only, no backend)
auth0 apps create --name "My SPA" --type spa \
  --auth-method None \
  --callbacks "http://localhost:3000" \
  --logout-urls "http://localhost:3000" \
  --origins "http://localhost:3000" \
  --web-origins "http://localhost:3000" \
  --json

# Regular web app (Next.js, Express, server-rendered)
auth0 apps create --name "My Web App" --type regular \
  --callbacks "http://localhost:3000/api/auth/callback" \
  --logout-urls "http://localhost:3000" \
  --json

# Machine-to-Machine (backend service, cron job, CLI tool)
auth0 apps create --name "My API Service" --type m2m --json

# Native (iOS, Android, React Native)
auth0 apps create --name "My Mobile App" --type native --auth-method None --json

# Resource Server (API + client in one entity)
auth0 apps create --name "My API Client" --type resource_server \
  --resource-server-identifier "https://api.example.com" \
  --json
```

| Flag | Short | Description |
|------|-------|-------------|
| `--name` | `-n` | **Required.** Application name |
| `--type` | `-t` | **Required.** One of: `native`, `spa`, `regular`, `m2m`, `resource_server` |
| `--description` | `-d` | Description (max 140 chars) |
| `--callbacks` | `-c` | Comma-separated callback URLs. Must include protocol (https://). |
| `--origins` | `-o` | Allowed CORS origin URLs. Supports subdomain wildcards (e.g., `https://*.contoso.com`). |
| `--web-origins` | `-w` | Allowed web origins for Cross-Origin Auth, Device Flow, and web message response mode |
| `--logout-urls` | `-l` | Allowed logout redirect URLs. Supports subdomain wildcards. |
| `--auth-method` | `-a` | Token endpoint auth: `None` (public app), `Post` (HTTP POST), or `Basic` (HTTP Basic) |
| `--grants` | `-g` | Grant types: code, implicit, refresh-token, credentials, password, password-realm, mfa-oob, mfa-otp, mfa-recovery-code, device-code |
| `--metadata` | | Key-value pairs (max 255 chars each). Repeatable: `--metadata "foo=bar" --metadata "baz=qux"` or comma-separated: `--metadata "foo=bar,baz=qux"` |
| `--resource-server-identifier` | | API identifier (only for `resource_server` type, cannot be changed after creation) |
| `--refresh-token` | `-z` | Refresh token config as JSON |
| `--reveal-secrets` | `-r` | Show secrets in output |
| `--json` | | JSON output |

### apps update

```bash
auth0 apps update <client-id> --name "New Name" --json
auth0 apps update <client-id> --callbacks "http://localhost:3000,https://myapp.com" --json
```

Same flags as `create` (except `--type` and `--resource-server-identifier` cannot change app type after creation).

### apps delete

```bash
auth0 apps delete <client-id>
auth0 apps delete <client-id> --force          # skip confirmation
auth0 apps delete <id1> <id2> <id3> --force    # batch delete
```

### apps open / use

```bash
auth0 apps open <client-id>     # opens settings in Auth0 Dashboard
auth0 apps use <client-id>      # set as default app for CLI session
auth0 apps use --none            # clear default app
```

### apps session-transfer

Manage session transfer settings for native-to-web app transitions.

```bash
auth0 apps session-transfer show <client-id> --json
auth0 apps session-transfer update <client-id> \
  --can-create-token \
  --allowed-auth-methods cookie,query \
  --enforce-device-binding ip \
  --json
```

| Flag | Short | Description |
|------|-------|-------------|
| `--can-create-token` | `-t` | Allow creation of session transfer tokens |
| `--allowed-auth-methods` | `-m` | Auth methods: cookie, query |
| `--enforce-device-binding` | `-e` | Device binding: none, ip, or asn |

---

## APIs

Manage Auth0 API resources (Resource Servers). Register these when you want to protect a backend API with Auth0 tokens.

**Key distinction:** `apps` = the client requesting tokens. `apis` = the resource accepting tokens.

**Alias:** `auth0 resource-servers`

### apis list

```bash
auth0 apis list --json
auth0 apis list --number 50 --json-compact
```

| Flag | Short | Default | Description |
|------|-------|---------|-------------|
| `--number` | `-n` | 100 | Number of APIs to retrieve (1–1000) |
| `--json` / `--json-compact` / `--csv` | | | Output format |

### apis show

```bash
auth0 apis show <api-id|api-audience> --json
auth0 apis show <api-id|api-audience> --json-compact
```

Note: accepts either the API ID or the audience identifier.

### apis create

```bash
auth0 apis create --name "My Backend API" --identifier "https://api.myapp.com" --json
auth0 apis create --name "My API" --identifier "https://api.myapp.com" \
  --scopes "read:data,write:data" \
  --token-lifetime 3600 \
  --offline-access \
  --json
```

| Flag | Short | Default | Description |
|------|-------|---------|-------------|
| `--name` | `-n` | | **Required.** API name |
| `--identifier` | `-i` | | **Required.** Unique audience URI. Cannot be changed after creation. |
| `--scopes` | `-s` | | Comma-separated list of scopes (permissions) |
| `--token-lifetime` | `-l` | 86400 | Access token validity in seconds (default: 1 day) |
| `--offline-access` | `-o` | false | Allow issuing refresh tokens |
| `--signing-alg` | | RS256 | Signing algorithm: HS256, RS256. PS256 via addon. |
| `--subject-type-authorization` | | | JSON access policies for user/client flows. E.g., `'{"user":{"policy":"require_client_grant"},"client":{"policy":"deny_all"}}'` |
| `--json` / `--json-compact` | | | Output format |

The `--identifier` becomes the `audience` parameter in token requests. Use a URL format by convention, but it doesn't need to resolve to a real endpoint.

### apis update

```bash
auth0 apis update <api-id|api-audience> --name "New Name" --scopes "read:data,write:data,delete:data" --json
```

Same flags as `create` except `--identifier` cannot be changed.

### apis delete

```bash
auth0 apis delete <api-id|api-audience>
auth0 apis delete <id1> <id2> --force    # batch delete
```

### apis scopes list

```bash
auth0 apis scopes list <api-id|api-audience> --json
auth0 apis scopes list <api-id|api-audience> --json-compact
```

Lists the scopes defined on an API. To update scopes, use `auth0 apis update <id> --scopes "..."`.

### apis open

```bash
auth0 apis open <api-id|api-audience>    # opens settings in dashboard
```

---

## Users

Create, search, inspect, or manage users in your tenant.

### users search

```bash
auth0 users search --query "email:user@example.com" --json
auth0 users search --query "email:*@mycompany.com" --sort "created_at:-1" --number 10 --json-compact
auth0 users search --query 'app_metadata.role:"admin"' --json-compact
```

| Flag | Short | Default | Description |
|------|-------|---------|-------------|
| `--query` | `-q` | | **Required.** Lucene query syntax. E.g., `email:"user@*.com" OR (user_id:"user-id-123" AND name:"Bob")` |
| `--sort` | `-s` | | Sort field and order. Use `field:1` for ascending, `field:-1` for descending. E.g., `created_at:-1` |
| `--number` | `-n` | 50 | Number of users to retrieve (1–1000) |
| `--picker` | `-p` | false | Interactive picker to view user details |
| `--json` / `--json-compact` / `--csv` | | | Output format |

### users search-by-email

```bash
auth0 users search-by-email <email> --json
auth0 users search-by-email user@example.com --json-compact
```

Simpler alternative to `search` when you just need an exact email match.

### users create

```bash
auth0 users create \
  --connection-name "Username-Password-Authentication" \
  --email "testuser@example.com" \
  --password "$USER_PASSWORD" \
  --name "Test User" \
  --json
```

| Flag | Short | Description |
|------|-------|-------------|
| `--connection-name` | `-c` | **Required.** Database connection name |
| `--email` | `-e` | User email |
| `--password` | `-p` | Initial password (mandatory for non-SMS connections) |
| `--name` | `-n` | Full name |
| `--username` | `-u` | Username (only if the connection requires it) |
| `--phone-number` | `-m` | Phone number |
| `--json` / `--json-compact` | | Output format |

`Username-Password-Authentication` is the default database connection name unless your tenant has a custom one.

### users show

```bash
auth0 users show <user-id> --json
```

User IDs follow the format `auth0|<id>` for database users, `google-oauth2|<id>` for Google, etc. Shows warning if user is blocked.

### users update

```bash
auth0 users update <user-id> --name "Updated Name" --json
auth0 users update <user-id> --email "new@example.com" --blocked false --json
```

| Flag | Short | Description |
|------|-------|-------------|
| `--connection-name` | `-c` | Database connection name |
| `--name` | `-n` | Full name |
| `--email` | `-e` | Email |
| `--username` | `-u` | Username |
| `--password` | `-p` | Password |
| `--phone-number` | `-m` | Phone number |
| `--blocked` | `-b` | Block/unblock user authentication |
| `--json` / `--json-compact` | | Output format |

### users delete

```bash
auth0 users delete <user-id>
auth0 users delete <id1> <id2> <id3> --force    # batch delete
```

### users import

Bulk import users. File size limit is 500KB per job — start multiple imports for larger datasets.

```bash
auth0 users import \
  --connection-name "Username-Password-Authentication" \
  --template "Basic Example" \
  --upsert \
  --json

auth0 users import \
  --connection-name "Username-Password-Authentication" \
  --users '[{"email":"user1@example.com","password":"pass1"}]' \
  --json
```

| Flag | Short | Description |
|------|-------|-------------|
| `--connection-name` | `-c` | **Required.** Database connection name |
| `--template` | `-t` | JSON template: `Empty`, `Basic Example`, `Custom Password Hash Example`, `MFA Factors Example` |
| `--users` | `-u` | JSON array of users (mutually exclusive with `--template`) |
| `--upsert` | | When true, updates pre-existing users that match on email |
| `--email-results` | | Send completion email to tenant owners (default: true) |

### users blocks

Manage brute-force protection blocks. Use when a user reports being locked out.

```bash
auth0 users blocks list <user-id-or-email> --json              # list blocks
auth0 users blocks list user@example.com --json-compact
auth0 users blocks unblock <user-id-or-email>                  # remove blocks
auth0 users blocks unblock user1@example.com user2@example.com # batch unblock
```

Accepts user ID, username, email, or phone number as identifier.

### users roles

Manage a user's role assignments. For RBAC (Role-Based Access Control).

```bash
auth0 users roles show <user-id> --json                            # list assigned roles
auth0 users roles show <user-id> --json-compact                    # compact JSON output
auth0 users roles assign <user-id> --roles <role-id1>,<role-id2>   # assign roles
auth0 users roles remove <user-id> --roles <role-id>               # remove roles
```

| Flag | Short | Description |
|------|-------|-------------|
| `--roles` | `-r` | **Required.** Comma-separated role IDs |
| `--number` | `-n` | Number of roles to retrieve (for `show`) |

### users open

```bash
auth0 users open <user-id>    # opens user settings in dashboard
```

---

## Roles

Create roles and manage permissions for RBAC (Role-Based Access Control). Roles are containers for permissions — you assign permissions to roles, then assign roles to users.

### roles list / show / create / update / delete

```bash
auth0 roles list --json
auth0 roles list --json-compact

auth0 roles show <role-id> --json
auth0 roles show <role-id> --json-compact

auth0 roles create --name "admin" --description "Full admin access" --json
auth0 roles create --name "editor" --description "Can edit content" --json-compact

auth0 roles update <role-id> --name "super-admin" --description "Updated description" --json

auth0 roles delete <role-id>
auth0 roles delete <role-id> --force
```

| Flag | Short | Description |
|------|-------|-------------|
| `--name` | `-n` | **Required (create).** Role name |
| `--description` | `-d` | **Required (create).** Role description |
| `--number` | `-n` | Number of roles to retrieve (for `list`, default 100) |
| `--json` / `--json-compact` / `--csv` | | Output format |
| `--force` | | Skip confirmation (for `delete`) |

### roles permissions

Add or remove API permissions (scopes) from a role.

```bash
auth0 roles permissions list <role-id> --json
auth0 roles permissions list <role-id> --json-compact

auth0 roles permissions add <role-id> \
  --api-id <api-id> \
  --permissions "read:data,write:data" \
  --json

auth0 roles permissions remove <role-id> \
  --api-id <api-id> \
  --permissions "write:data" \
  --json
```

| Flag | Short | Description |
|------|-------|-------------|
| `--api-id` | `-a` | **Required.** API (resource server) ID |
| `--permissions` | `-p` | **Required.** Comma-separated permissions to add/remove |

**Typical RBAC workflow:**
```bash
# 1. Create a role
auth0 roles create --name "editor" --description "Content editors" --json
# 2. Add API permissions to the role
auth0 roles permissions add <role-id> --api-id <api-id> --permissions "read:articles,write:articles" --json
# 3. Assign role to a user
auth0 users roles assign <user-id> --roles <role-id>
# 4. Verify role assignment
auth0 users roles show <user-id> --json-compact
```

---

## Organizations

B2B / multi-tenant scenarios where your customers are companies, each with their own set of users, connections, and branding.

**Alias:** `auth0 orgs`

### organizations list / show / create / update / delete

```bash
auth0 orgs list --json
auth0 orgs show <org-id> --json

auth0 orgs create --name "acme-corp" --display "Acme Corporation" \
  --logo "https://acme.com/logo.png" \
  --accent "#FF6600" --background "#FFFFFF" \
  --json

auth0 orgs update <org-id> --display "Acme Corp Inc." --accent "#0066FF" --json

auth0 orgs delete <org-id> --force
```

| Flag | Short | Description |
|------|-------|-------------|
| `--name` | `-n` | **Required (create).** Organization name (URL-safe slug) |
| `--display` | `-d` | Display name shown in UI |
| `--logo` | `-l` | Logo URL |
| `--accent` | `-a` | Accent color (hex) for organization branding |
| `--background` | `-b` | Background color (hex) |
| `--metadata` | `-m` | Key-value metadata |

### organizations members / roles / invitations

```bash
# Members
auth0 orgs members list <org-id> --json

# Roles within an organization
auth0 orgs roles list <org-id> --json
auth0 orgs roles members list <org-id> --role-id <role-id> --json

# Invitations
auth0 orgs invitations list --org-id <org-id> --json
auth0 orgs invitations show --org-id <org-id> --invitation-id <id> --json
auth0 orgs invitations create --org-id <org-id> \
  --inviter-name "Admin" \
  --invitee-email "new@acme.com" \
  --client-id <app-client-id> \
  --roles <role-id1>,<role-id2> \
  --json
auth0 orgs invitations delete --org-id <org-id> --invitation-id <id> --force
```

---

## Actions

Create and deploy serverless functions that run at specific points in the Auth0 pipeline (login, registration, M2M token exchange, etc.). Actions replaced the deprecated Rules system.

### actions list / show / create / update / delete / deploy

```bash
auth0 actions list --json

auth0 actions show <action-id> --json

auth0 actions create \
  --name "Add Custom Claims" \
  --trigger "post-login" \
  --code 'exports.onExecutePostLogin = async (event, api) => { api.accessToken.setCustomClaim("role", event.user.app_metadata.role); }' \
  --json

auth0 actions update <action-id> \
  --name "Add Custom Claims v2" \
  --code 'exports.onExecutePostLogin = async (event, api) => { /* updated */ }' \
  --json

auth0 actions deploy <action-id>    # deploy a draft action

auth0 actions delete <action-id> --force

auth0 actions open <action-id>      # open in dashboard
auth0 actions diff <action-id>      # diff between versions (interactive)
```

| Flag | Short | Description |
|------|-------|-------------|
| `--name` | `-n` | Action name |
| `--trigger` | `-t` | **Required (create).** Trigger: `post-login`, `credentials-exchange`, `pre-user-registration`, `post-user-registration`, `post-change-password`, `send-phone-message` |
| `--code` | `-c` | **Required (create).** JavaScript code for the action |
| `--dependency` | `-d` | npm dependencies (repeatable, format: `name@version`) |
| `--secret` | `-s` | Secrets (repeatable, format: `KEY=value`) |
| `--runtime` | `-r` | Node.js runtime version |
| `--force` | | Skip confirmation (for `update`/`delete`) |
| `--json` / `--json-compact` | | Output format |

**Important:** After creating or updating an action, you must `deploy` it for the changes to take effect in live traffic.

---

## Logs

When something breaks in an auth flow, `logs tail` is your first debugging tool — faster than opening the dashboard. It shows live events from your tenant.

### logs tail

```bash
auth0 logs tail --json
auth0 logs tail --filter "type:f" --json-compact     # failed logins only
auth0 logs tail --filter "type:s" --json-compact     # successful logins only
auth0 logs tail --filter "type:fp" --json-compact    # failed password changes
```

| Flag | Short | Default | Description |
|------|-------|---------|-------------|
| `--filter` | `-f` | | Lucene query syntax. See [query syntax docs](https://auth0.com/docs/logs/log-search-query-syntax). |
| `--number` | `-n` | 50 | Number of log entries to show (1–1000) |

Polls every 2 seconds and deduplicates events.

### logs list

```bash
auth0 logs list --json
auth0 logs list --filter "type:f" --number 20 --json-compact
```

| Flag | Short | Default | Description |
|------|-------|---------|-------------|
| `--filter` | `-f` | | Lucene query syntax filter |
| `--number` | `-n` | 50 | Number of entries (1–1000) |
| `--picker` | `-p` | false | Interactive picker to view log details |
| `--json` / `--json-compact` / `--csv` | | | Output format |

### Common log type codes

| Code | Event | When to look for it |
|------|-------|---------------------|
| `s` | Success login | Confirm a login completed |
| `f` | Failed login | Wrong password, locked account, blocked IP |
| `slo` | Success logout | Confirm logout flow worked |
| `ss` | Silent auth success | SPA token renewal succeeded |
| `fs` | Silent auth failure | SPA token renewal failed — user sees login prompt |
| `fp` | Failed password change | Password change issues |
| `sce` | Success change email | Email update completed |

---

## Domains

Configure custom domains on your Auth0 tenant. Custom domains replace `<tenant>.auth0.com` with your own branded domain (e.g., `auth.myapp.com`).

```bash
auth0 domains list --json

auth0 domains show <domain-id> --json

auth0 domains create --domain "auth.myapp.com" --type "auth0_managed_certs" --json

auth0 domains verify <domain-id> --json    # verify DNS configuration

auth0 domains delete <domain-id> --force

auth0 domains default show --json           # show the default custom domain
auth0 domains default set --domain <id>     # set the default
```

| Flag | Short | Description |
|------|-------|-------------|
| `--domain` | `-d` | **Required (create).** The custom domain (e.g., `auth.myapp.com`) |
| `--type` | `-t` | Domain type (e.g., `auth0_managed_certs`, `self_managed_certs`) |
| `--policy` | `-p` | TLS policy |
| `--ip-header` | `-i` | Custom IP header for proxy setups |

---

## Universal Login

Configure and brand your Auth0 Universal Login page — the hosted login page users see.

**Alias:** `auth0 ul`

```bash
auth0 ul show --json                # show current UL configuration

auth0 ul update \
  --accent "#FF6600" \
  --background "#FFFFFF" \
  --logo "https://myapp.com/logo.png" \
  --favicon "https://myapp.com/favicon.ico" \
  --font "https://fonts.googleapis.com/css2?family=Inter" \
  --json

auth0 ul customize                  # set rendering mode (new/classic/advanced)
```

| Flag | Short | Description |
|------|-------|-------------|
| `--accent` | `-a` | Accent color (hex) for buttons and links |
| `--background` | `-b` | Background color (hex) |
| `--logo` | `-l` | Logo URL |
| `--favicon` | `-f` | Favicon URL |
| `--font` | `-c` | Font URL (Google Fonts or custom) |

### universal-login templates

```bash
auth0 ul templates show             # show current custom HTML template
auth0 ul templates update           # update the custom HTML template
```

### universal-login prompts (custom text)

Customize the text shown on login prompts for each language.

```bash
auth0 ul prompts show <prompt> --language <lang> --json
auth0 ul prompts update <prompt> --language <lang> --text '{...}' --json
```

| Flag | Short | Description |
|------|-------|-------------|
| `--language` | `-l` | Language code (e.g., `en`, `es`, `fr`) |
| `--text` | `-t` | JSON object with custom text keys |

---

## Terraform

Export your current Auth0 tenant configuration as Terraform HCL — useful for infrastructure as code, environment replication, or migrating to Terraform management.

```bash
auth0 terraform generate
auth0 terraform generate --output-dir ./terraform
auth0 terraform generate --output-dir ./terraform --resources "auth0_client,auth0_connection"
```

| Flag | Short | Description |
|------|-------|-------------|
| `--output-dir` | `-o` | Directory to write Terraform files |
| `--resources` | `-r` | Comma-separated list of resource types to export (defaults to all) |
| `--tf-version` | `-v` | Terraform provider version |

---

## Test

Quickly verify that authentication works for a specific application without building a UI. Opens a browser to run the actual login flow.

```bash
auth0 test login <client-id>
auth0 test login <client-id> --connection-name "google-oauth2"
auth0 test login <client-id> --audience "https://api.myapp.com" --scopes "openid profile email"
auth0 test login <client-id> --organization "org_123abc"
```

| Flag | Short | Description |
|------|-------|-------------|
| `--connection-name` | `-c` | Specific connection to use (e.g., `google-oauth2`, `Username-Password-Authentication`) |
| `--audience` | `-a` | API audience to request in the token |
| `--scopes` | `-s` | Scopes to request |
| `--domain` | `-d` | Custom domain to use |
| `--organization` | `-o` | Organization ID or name |
| `--params` | `-p` | Additional authorization parameters |

After creating an app or configuring a connection, use `auth0 test login` to verify the flow works end-to-end before integrating into your application code.

---

## Quickstarts

Get working sample applications for your framework/language.

```bash
auth0 quickstarts list --json            # list available quickstarts
auth0 quickstarts download               # download a quickstart (interactive)
auth0 quickstarts setup                  # download and configure with your app credentials
```

**Alias:** `auth0 qs`

---

## Attack Protection

Manage Auth0's built-in attack protection features.

**Alias:** `auth0 ap`

```bash
# Brute-force protection
auth0 protection brute-force-protection show --json
auth0 protection brute-force-protection update --enabled true

# Breached password detection
auth0 protection breached-password-detection show --json
auth0 protection breached-password-detection update --enabled true

# Suspicious IP throttling
auth0 protection suspicious-ip-throttling show --json
auth0 protection suspicious-ip-throttling update --enabled true

# Bot detection
auth0 protection bot-detection show --json
auth0 protection bot-detection update --enabled true

# Check/unblock IPs (under suspicious-ip-throttling)
auth0 protection suspicious-ip-throttling ips check <ip>
auth0 protection suspicious-ip-throttling ips unblock <ip>
```

---

## Log Streams

Send Auth0 tenant logs to external services for monitoring, alerting, or long-term storage.

```bash
auth0 logs streams list --json
auth0 logs streams show <stream-id> --json
auth0 logs streams delete <stream-id> --force
```

Supported stream types (each has its own `create`/`update` sub-command):
- **eventbridge** — AWS EventBridge
- **eventgrid** — Azure Event Grid
- **http** — Custom webhook
- **datadog** — Datadog
- **splunk** — Splunk
- **sumo** — Sumo Logic

```bash
auth0 logs streams create http     # interactive setup for webhook stream
auth0 logs streams create datadog  # interactive setup for Datadog
```

---

## IPs

```bash
auth0 ips check <ip-address>      # check if an IP is blocked
auth0 ips unblock <ip-address>    # unblock an IP
```

---

## Raw API Mode

When a dedicated command doesn't exist for what you need, `auth0 api` lets you call any [Auth0 Management API v2](https://auth0.com/docs/api/management/v2) endpoint directly with your tenant credentials already handled. Think of it as `curl` for the Management API — but without managing tokens.

```bash
auth0 api <method> <url-path> [flags]
```

| Flag | Short | Description |
|------|-------|-------------|
| `--data` | `-d` | JSON payload for POST/PATCH/PUT requests. Can also pipe via stdin. |
| `--query` | `-q` | Query parameters (repeatable: `-q "page=0" -q "per_page=5"`) |
| `--force` | | Skip confirmation on DELETE requests |

**Method defaults:** GET when no `--data` is provided, POST when `--data` is provided. You can explicitly set the method as the first argument.

The `<url-path>` is relative to `/api/v2/` — do NOT include the full URL. E.g., `tenants/settings`, not `https://tenant.auth0.com/api/v2/tenants/settings`.

**Examples:**

```bash
# Connections (no dedicated CLI command for full CRUD)
auth0 api get connections
auth0 api get connections/<connection-id>

# Client grants
auth0 api get client-grants
auth0 api post client-grants --data '{"client_id":"...","audience":"...","scope":["read:data"]}'

# Tenant settings
auth0 api get tenants/settings

# Daily stats
auth0 api get stats/daily -q "from=20240101" -q "to=20240131"

# Paginate results
auth0 api get clients -q "page=0" -q "per_page=10"

# Pipe JSON from file
cat config.json | auth0 api post clients

# Hooks (deprecated but still accessible)
auth0 api get hooks
```

**Scope errors:** If a call fails with 403 / insufficient_scope, re-login with the missing scope: `auth0 login --scopes "read:client_grants"`.

---

## Output Formatting

Append `--json` to any list/show/create/update command to get machine-readable JSON. Three modes (mutually exclusive):

| Flag | Description |
|------|-------------|
| `--json` | Pretty-printed JSON with indentation |
| `--json-compact` | Compact single-line JSON (useful for piping to jq) |
| `--csv` | CSV format (for spreadsheets) |

**Use `--json` when:**
- Debugging and you want the full raw response with readable indentation
- Inspecting a single resource in detail

**Use `--json-compact` when:**
- Piping to `jq` — compact output avoids whitespace overhead
- Scripting or automating CLI calls where each record should be one line
- Chaining commands in a pipeline

```bash
# Pretty-printed JSON for human inspection
auth0 apps show <client-id> --json

# Compact JSON piped to jq — preferred for scripting
auth0 apps list --json-compact | jq '.[] | {client_id, name}'

# Extract a user's email and ID
auth0 users show <user-id> --json-compact | jq '{id: .user_id, email: .email}'

# Get all API identifiers
auth0 apis list --json-compact | jq '.[].identifier'

# Search users and pipe to jq
auth0 users search --query "email:*@mycompany.com" --json-compact | jq '.[].user_id'

# Tail logs as compact JSON for aggregation
auth0 logs tail --json-compact

# List roles as compact JSON
auth0 roles list --json-compact | jq '.[].name'

# CSV output for spreadsheets
auth0 apps list --csv > apps.csv
```

The default text output is for human reading only — it truncates long values and uses ANSI colors that break parsing. Always use `--json` or `--json-compact` when you need to extract values programmatically. Prefer `--json-compact` when piping to `jq` or other tools.

---

## Shared Flags

These flags are available across most commands:

| Flag | Description |
|------|-------------|
| `--tenant` | Target a specific tenant (overrides active tenant) |
| `--no-input` | Disable all interactive prompts (for scripting) |
| `--no-color` | Disable colored output |
| `--debug` | Enable debug mode (verbose HTTP logging) |
