---
name: auth0-cli
description: >
  Use when running Auth0 CLI commands to manage tenant resources — creating apps or APIs, managing users, roles, organizations, actions, log streams, custom domains, or Universal Login config. Also use when calling the Auth0 Management API directly via the CLI.
license: Apache-2.0
metadata:
  author: Auth0 <support@auth0.com>
  version: '1.0.0'
  openclaw:
    emoji: "\U0001F510"
    homepage: https://github.com/auth0/agent-skills
    requires:
      bins:
        - auth0
    os:
      - darwin
      - linux
    install:
      - id: brew
        kind: brew
        package: auth0/auth0-cli/auth0
        bins: [auth0]
        label: 'Install Auth0 CLI (brew)'
---

# Auth0 CLI — Command Reference

The Auth0 CLI (`auth0`) lets you manage your tenant from the terminal. Install it via Homebrew (`brew install auth0/auth0-cli/auth0`). For complete flag definitions and examples, see the [Full CLI Reference](references/cli.md).

---

## Before You Start: Authenticate

```bash
auth0 login                          # interactive device-code login
auth0 login --scopes "read:client_grants"  # request extra scopes if 403
auth0 login --domain <tenant>.auth0.com --client-id <id> --client-secret "$AUTH0_CLIENT_SECRET"  # CI/CD
```

See [Authentication Details](references/cli.md#authentication) for machine login with JWT, tenant management, and logout.

---

## Quick Decision Guide

| What you're doing | Command to use |
|-------------------|---------------|
| Setting up a new project | `auth0 apps create --type spa\|regular\|m2m\|native --json` |
| Need a client ID or secret | `auth0 apps show <id> -r --json` |
| Registering a backend API | `auth0 apis create --identifier "https://..." --json` |
| Finding a user's ID | `auth0 users search --query "email:..." --json` |
| Creating/managing roles (RBAC) | `auth0 roles create` / `auth0 users roles assign` |
| B2B multi-tenancy | `auth0 orgs create` |
| Custom login logic | `auth0 actions create --trigger post-login --json` |
| Branding the login page | `auth0 ul update --logo ... --accent ...` |
| Custom domain for login | `auth0 domains create --domain "auth.myapp.com" --json` |
| Debugging a failed login | `auth0 logs tail --filter "type:f" --json-compact` |
| Testing a login flow | `auth0 test login <client-id>` |
| Exporting config as Terraform | `auth0 terraform generate --output-dir ./terraform` |
| Managing connections, grants, hooks | `auth0 api get <path>` |
| Scripting / parsing output | Add `--json` or `--json-compact` to any command |
| Security hardening | `auth0 protection brute-force-protection update --enabled true` |
| Routing logs externally | `auth0 logs streams create datadog\|http\|splunk` |
| Bulk importing users | `auth0 users import --connection-name ... --users '...' --json` |

---

## Command Overview

### Apps — Manage Applications

Create or inspect Auth0 applications (client ID, secret, callback URLs, app type). Alias: `auth0 clients`.

```bash
auth0 apps create --name "My SPA" --type spa \
  --auth-method None \
  --callbacks "http://localhost:3000" \
  --logout-urls "http://localhost:3000" \
  --origins "http://localhost:3000" --json

auth0 apps list --json-compact
auth0 apps show <client-id> --json
auth0 apps update <client-id> --callbacks "http://localhost:3000,https://myapp.com" --json
auth0 apps delete <client-id> --force
```

App types: `spa`, `regular`, `m2m`, `native`, `resource_server`

Full details: [Apps Reference](references/cli.md#apps)

### APIs — Manage API Resources

Register backend APIs (Resource Servers) to protect with Auth0 tokens. Alias: `auth0 resource-servers`.

```bash
auth0 apis create --name "My API" --identifier "https://api.myapp.com" \
  --scopes "read:data,write:data" --token-lifetime 3600 --json

auth0 apis list --json-compact
auth0 apis scopes list <api-id> --json
```

**Key distinction:** `apps` = the client requesting tokens. `apis` = the resource accepting tokens.

Full details: [APIs Reference](references/cli.md#apis)

### Users — Manage Users

Create, search, inspect, import, and manage users in your tenant.

```bash
auth0 users search --query "email:user@example.com" --json
auth0 users search-by-email user@example.com --json-compact
auth0 users create --connection-name "Username-Password-Authentication" \
  --email "test@example.com" --password "$USER_PASSWORD" --json
auth0 users show <user-id> --json
auth0 users blocks list <email> --json
auth0 users blocks unblock <email>
auth0 users import --connection-name "Username-Password-Authentication" \
  --users '[...]' --upsert --json
```

Full details: [Users Reference](references/cli.md#users)

### Roles — Manage RBAC Roles

Create roles, assign permissions, and assign roles to users. The CLI has dedicated commands for all role operations.

```bash
auth0 roles create --name "editor" --description "Can edit content" --json
auth0 roles permissions add <role-id> --api-id <api-id> --permissions "read:data,write:data" --json
auth0 users roles assign <user-id> --roles <role-id>
auth0 users roles show <user-id> --json-compact
```

Full details: [Roles Reference](references/cli.md#roles)

### Organizations — B2B Multi-Tenancy

Manage organizations for B2B SaaS scenarios. Alias: `auth0 orgs`.

```bash
auth0 orgs create --name "acme-corp" --display "Acme Corporation" \
  --logo "https://acme.com/logo.png" --accent "#FF6600" --json
auth0 orgs members list <org-id> --json
auth0 orgs invitations create --org-id <org-id> --invitee-email "new@acme.com" \
  --inviter-name "Admin" --client-id <id> --json
```

Full details: [Organizations Reference](references/cli.md#organizations)

### Actions — Serverless Auth Pipeline

Create and deploy serverless functions at auth pipeline trigger points. Replaces deprecated Rules.

```bash
auth0 actions create --name "Add Claims" --trigger "post-login" \
  --code 'exports.onExecutePostLogin = async (event, api) => { ... }' --json
auth0 actions deploy <action-id>
```

Triggers: `post-login`, `credentials-exchange`, `pre-user-registration`, `post-user-registration`, `post-change-password`, `send-phone-message`

**Important:** You must `deploy` after creating or updating for changes to take effect.

Full details: [Actions Reference](references/cli.md#actions)

### Logs — Debugging & Monitoring

```bash
auth0 logs tail --filter "type:f" --json-compact    # real-time failed logins
auth0 logs list --filter "type:f" --number 20 --json-compact  # historical
```

Common codes: `s` (success), `f` (failed login), `slo` (logout), `fs` (silent auth failure)

Full details: [Logs Reference](references/cli.md#logs)

### Domains — Custom Domains

```bash
auth0 domains create --domain "auth.myapp.com" --type "auth0_managed_certs" --json
auth0 domains verify <domain-id> --json
```

Full details: [Domains Reference](references/cli.md#domains)

### Universal Login — Branding

```bash
auth0 ul update --accent "#FF6600" --background "#FFFFFF" \
  --logo "https://myapp.com/logo.png" --json
```

Full details: [Universal Login Reference](references/cli.md#universal-login)

### Terraform — Export as IaC

```bash
auth0 terraform generate --output-dir ./terraform --resources "auth0_client,auth0_connection"
```

Full details: [Terraform Reference](references/cli.md#terraform)

### Test — Verify Login Flows

```bash
auth0 test login <client-id>
auth0 test login <client-id> --audience "https://api.myapp.com" --scopes "openid profile email"
```

Full details: [Test Reference](references/cli.md#test)

### Attack Protection — Security Hardening

```bash
auth0 protection brute-force-protection update --enabled true
auth0 protection breached-password-detection update --enabled true
auth0 protection bot-detection update --enabled true
```

Full details: [Attack Protection Reference](references/cli.md#attack-protection)

### Log Streams — External Routing

```bash
auth0 logs streams create datadog    # interactive setup
auth0 logs streams create http       # custom webhook
auth0 logs streams list --json
```

Supported: eventbridge, eventgrid, http, datadog, splunk, sumo

Full details: [Log Streams Reference](references/cli.md#log-streams)

### Raw API Mode — Direct Management API Access

When a dedicated command doesn't exist, `auth0 api` calls Management API v2 endpoints directly.

```bash
auth0 api get connections
auth0 api post client-grants --data '{"client_id":"...","audience":"...","scope":["read:data"]}'
auth0 api get stats/daily -q "from=20240101" -q "to=20240131"
```

Full details: [Raw API Reference](references/cli.md#raw-api-mode)

---

## Output Formatting

Always use `--json` or `--json-compact` for machine-readable output. Three modes (mutually exclusive):

| Flag | When to use |
|------|-------------|
| `--json` | Human inspection, debugging — pretty-printed with indentation |
| `--json-compact` | Piping to `jq`, scripting, pipelines — compact single-line |
| `--csv` | Spreadsheets and tabular export |

```bash
auth0 apps list --json-compact | jq '.[] | {client_id, name}'
auth0 users show <user-id> --json-compact | jq '{id: .user_id, email: .email}'
auth0 roles list --json-compact | jq '.[].name'
```

Full details: [Output Formatting Reference](references/cli.md#output-formatting)

---

## Reference Documentation

Complete CLI reference with all flags, examples, and usage patterns:
- [Setup Guide](references/setup.md) — installation, authentication, CI/CD configuration
- [Authentication](references/cli.md#authentication) — login modes, tenant management, scopes
- [Apps](references/cli.md#apps) — create, list, show, update, delete, session-transfer
- [APIs](references/cli.md#apis) — create, scopes, token lifetime
- [Users](references/cli.md#users) — search, create, import, blocks, roles
- [Roles](references/cli.md#roles) — RBAC setup, permissions management
- [Organizations](references/cli.md#organizations) — B2B, members, invitations
- [Actions](references/cli.md#actions) — pipeline triggers, deploy workflow
- [Logs](references/cli.md#logs) — tail, list, type codes
- [Domains](references/cli.md#domains) — custom domains, verification
- [Universal Login](references/cli.md#universal-login) — branding, templates, prompts
- [Terraform](references/cli.md#terraform) — IaC export
- [Test](references/cli.md#test) — login flow verification
- [Attack Protection](references/cli.md#attack-protection) — brute-force, breach, bot detection
- [Log Streams](references/cli.md#log-streams) — external service routing
- [Raw API Mode](references/cli.md#raw-api-mode) — direct Management API access
- [Output Formatting](references/cli.md#output-formatting) — --json, --json-compact, --csv
- [Shared Flags](references/cli.md#shared-flags) — --tenant, --no-input, --debug

---

## Related Skills

- `auth0-quickstart` — Initial Auth0 setup, framework detection
- `auth0-migration` — Migrate from other auth providers
- `auth0-mfa` — Multi-Factor Authentication setup

---

## References

- [Auth0 CLI Documentation](https://auth0.github.io/auth0-cli/)
- [Auth0 Management API v2](https://auth0.com/docs/api/management/v2)
- [Auth0 Documentation](https://auth0.com/docs)
