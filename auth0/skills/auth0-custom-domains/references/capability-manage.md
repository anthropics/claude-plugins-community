# Manage Existing Domains

Surgical edits on custom domains that already exist: list them, set or change the default, update TLS policy, configure the custom client IP header, set the relying party identifier for passkeys, and manage per-domain metadata. Intent-driven: the user says what they want in natural language and the skill maps it to the right API call.

**Not in scope here: changing certificate type.** The Management API rejects `type` on PATCH. `type` is fixed at create time. If the user wants to switch between `auth0_managed_certs` and `self_managed_certs`, route them to delete (**Remove a custom domain**) and recreate (**Set up a custom domain**). Coordinate the DNS and reverse-proxy cutover to avoid auth downtime.

## Pre-flight: confirm the active tenant

Before any PATCH or tenant-settings write, confirm the active Auth0 CLI tenant matches the one the user intends to modify. The Auth0 CLI is single-tenant; an unnoticed mismatch writes to the wrong tenant.

```bash
auth0 tenants list
```

Surface the active tenant to the user and require explicit confirmation ("the active tenant is `acme-prod`; proceed?"). If it's wrong, stop and have the user run `auth0 tenants use <tenant-name>`, then re-confirm before continuing.

## Load current state

After tenant confirmation, fetch the current custom domain list once. Cache it for the session so disambiguation prompts can show current values.

```bash
auth0 api get "custom-domains"
```

Also fetch tenant settings for the current default:

```bash
auth0 api get "tenants/settings"
```

Look at the `default_custom_domain_id` field.

## Intent mapping

Common user phrasings and what they map to:

| User says | Target |
|---|---|
| "list my custom domains" / "what domains do I have?" | Show the cached list: domain, status, cert type, default flag |
| "make {domain} the default" / "set default to {domain}" | `PATCH /tenants/settings` with `default_custom_domain_id` |
| "which one is the default?" | Read from cached tenant settings |
| "switch {domain} to self-managed" / "switch {domain} back to Auth0-managed" / "change cert type on {domain}" | Not supported via PATCH. Explain that `type` is fixed at create, and route to **Remove a custom domain** + **Set up a custom domain** to do a delete + recreate. Warn about downtime |
| "set the rpId on {domain} to example.com" / "bind passkeys at the root" / "change the passkey rpId" | See **Set the relying party identifier (passkeys)** below |
| "what's the rpId for {domain}?" / "where do passkeys bind for {domain}?" | Read `relying_party_identifier` from cached state; if unset, explain default is the domain hostname |
| "set the TLS policy to recommended" / "change TLS policy on {domain}" | See **Update TLS policy** below |
| "set the client IP header to cf-connecting-ip" / "Auth0 is behind Cloudflare, use the right IP header" | See **Configure the custom client IP header** below |
| "show me the CNAME value for {domain}" | Read `verification.methods[0].record` from cached state |
| "what's the status of {domain}?" | Read `status` from cached state |
| "add metadata to {domain}" / "tag {domain} with {key}={value}" | See **Manage domain metadata** below |
| "what metadata is on {domain}?" / "show metadata for {domain}" | Read `domain_metadata` from cached state |
| "remove the {key} metadata from {domain}" | See **Manage domain metadata** below |

For intents that don't match, ask the user to restate more specifically and list the supported operations.

## What PATCH accepts

The Management API accepts these fields on `PATCH /custom-domains/{id}`:

- `tls_policy`
- `custom_client_ip_header`
- `relying_party_identifier`
- `domain_metadata`

The API **rejects** `type`, `domain`, `verification_method`. To change any of those, delete and recreate.

## Set or change the default

```bash
auth0 api patch "custom-domains/default" --data '{"domain": "login.example.com"}'
```

The Auth0 CLI does not have a dedicated `auth0 domains default` subcommand; use the API passthrough above.

Effects to explain to the user:
- Notification-triggering Management API calls (password reset tickets, verification emails) will route through this domain when no `auth0-custom-domain` header is sent.
- Email template links will use this domain by default.
- Does not affect the `iss` claim on tokens issued for other custom domains on the same tenant; that's still determined per-request.

Before applying, show the diff: `current default: {value or "(none)"}` → `new default: {new value}`.

## Set the relying party identifier (passkeys)

`relying_party_identifier` controls what domain passkeys bind to. Default (when unset) is the custom domain hostname itself. Set it explicitly when the custom domain is a subdomain but you want passkeys usable at the parent domain.

### When users want this

- Custom domain is `login.example.com`, but the app also runs at `www.example.com` and a native iOS app with Associated Domains. Setting `relying_party_identifier: "example.com"` lets a passkey created during login work across all three surfaces.
- A B2B tenant serves multiple subdomains per customer and wants passkeys bound to the shared parent zone.

The RPID must be a registrable suffix of the custom domain (you can't set `google.com` as the RPID of `login.example.com`). WebAuthn / passkey clients enforce this at registration time.

### Execute the PATCH

```bash
auth0 api patch "custom-domains/<domainId>" --data '{
  "relying_party_identifier": "example.com"
}'
```

Before sending, show the diff: `current rpId: {value or "(default: domain hostname)"}` → `new rpId: {new value}`.

### Consequences to explain

- **Passkeys already registered against the old RPID stop working.** WebAuthn credentials are bound to the RPID at registration and cannot be re-mapped. Users with existing passkeys will need to register new ones on next login. Mention this before executing.
- No DNS changes required. No re-verification needed. The change takes effect on the next authentication.

### Clearing the RPID

To revert to the default (RPID = custom domain hostname), PATCH with `null`:

```bash
auth0 api patch "custom-domains/<domainId>" --data '{
  "relying_party_identifier": null
}'
```

## Update TLS policy

`tls_policy` governs the TLS posture for Auth0-managed certificate domains. Default and recommended value is `"recommended"`. Only set explicitly when a compliance mandate requires a specific policy.

```bash
auth0 api patch "custom-domains/<domainId>" --data '{
  "tls_policy": "recommended"
}'
```

No DNS change, no re-verification. Takes effect on the next handshake.

## Configure the custom client IP header

`custom_client_ip_header` tells Auth0 which request header carries the real client IP when traffic reaches Auth0 through a reverse proxy. Without this set, rate limiting and anomaly detection see the proxy's IP, not the end user's.

### Valid values

- `true-client-ip` — generic reverse proxy; Akamai uses this
- `cf-connecting-ip` — Cloudflare
- `x-forwarded-for` — most generic proxies, load balancers
- `x-azure-clientip` — Azure Front Door

Pick the value that matches what the proxy in front of Auth0 emits. Only one value at a time. If unsure, check the proxy's documentation for which header it populates with the original client IP.

### Execute the PATCH

```bash
auth0 api patch "custom-domains/<domainId>" --data '{
  "custom_client_ip_header": "cf-connecting-ip"
}'
```

To clear, PATCH with `null`:

```bash
auth0 api patch "custom-domains/<domainId>" --data '{
  "custom_client_ip_header": null
}'
```

No DNS change, no re-verification. Takes effect on the next request.

### Safety note

Only set this when there really is a trusted proxy in front of Auth0. If no proxy is injecting the header, an attacker can spoof the configured header to forge client IPs for rate-limit / anomaly bypass. The correct pattern: the proxy strips any incoming instance of the header from the public internet and re-emits it with the true source IP.

## Manage domain metadata

Each custom domain can carry up to **10 key-value pairs** as `domain_metadata`, with keys and values limited to **255 characters each** (Auth0's standard metadata convention, matching user `app_metadata` / application metadata / session metadata).

### Why users set domain metadata

The primary use case is feeding context to Auth0 Actions. Actions triggers expose `event.custom_domain.domain_metadata` on several flows (post-login, credentials-exchange, send-phone-message, custom email providers). Common patterns:

- Region tagging (`region: us-east`, `region: eu-west`) for routing in Actions
- Brand tagging (`brand: acme`, `brand: widgetco`) for multi-brand MCD tenants
- Environment tagging (`env: prod`, `env: staging`) for per-env behavior
- Partner / customer identifiers for B2B flows

Set the tag once on the domain; every authentication that hits that domain surfaces the tag to Actions without needing an extra lookup.

### Read current metadata

Metadata is returned as `domain_metadata` on the domain object. Load once at the start of the Manage existing domains flow (see top of this file); no extra call needed.

```bash
auth0 api get "custom-domains/<domainId>"
```

### Add or update metadata (canonical pattern: GET → merge → PATCH)

Always read current metadata, merge the user's changes into it locally, and PATCH the full merged object. This is correct under any PATCH semantics (shallow-merge or full-replace) and is the pattern to use every time:

1. GET current `domain_metadata` from the domain object (already cached from the start of this flow).
2. Merge the user's changes into the existing object client-side.
3. PATCH the full merged object.

```bash
auth0 api patch "custom-domains/<domainId>" --data '{
  "domain_metadata": {
    "region": "us-east",
    "brand": "acme"
  }
}'
```

The body above should contain the full post-merge object, not just the changed keys.

### Remove a key

Omit the key from the merged object and PATCH the full result. Don't rely on `null`-as-delete — submit only the keys that should remain.

```bash
# Current: { "region": "us-east", "brand": "acme" }
# User wants to drop "brand":
auth0 api patch "custom-domains/<domainId>" --data '{
  "domain_metadata": {
    "region": "us-east"
  }
}'
```

To clear all metadata, PATCH with an empty object:

```bash
auth0 api patch "custom-domains/<domainId>" --data '{
  "domain_metadata": {}
}'
```

### Constraints to enforce in the skill

Before any PATCH that writes metadata, check:
- Total keys after the write must be **≤ 10**. If the user tries to add an 11th, refuse and list the current keys so they can choose which to drop.
- Each key must be **≤ 255 characters**.
- Each value must be **≤ 255 characters**.
- Keys cannot contain UTF-8 private-use characters (Auth0 metadata convention).

If any constraint would be violated, block the write and surface the specific violation; don't rely on the API error message.

### Display format

When the user asks to see metadata:

```text
Metadata on login.example.com (2/10 keys used):

  region   us-east
  brand    acme
```

If no metadata is set, say that explicitly rather than showing an empty block.

## List output format

When the user asks "list" or "show my domains":

```text
Custom domains on this tenant (3):

  login.example.com         ready                 Auth0-managed  DEFAULT
  login-eu.example.com      ready                 Auth0-managed
  login-legacy.example.com  pending_verification  Self-managed

  (run the Troubleshoot verification flow to troubleshoot login-legacy.example.com)
```

## Batch multiple changes

If the user requests several changes in one session ("set the rpId on A to example.com, make B the default, add metadata to C"), stage them and apply as a batch. Show the consolidated diff before executing. Per-domain fields (`tls_policy`, `custom_client_ip_header`, `relying_party_identifier`, `domain_metadata`) can all be merged into a single PATCH per domain to avoid multiple round-trips.

For deletes, route to the Remove a custom domain flow rather than handling here. For cert-type changes, the API rejects `type` on PATCH; route to delete + recreate.

## Scope note

Changes made here don't write to DNS. None of the supported PATCH fields (`tls_policy`, `custom_client_ip_header`, `relying_party_identifier`, `domain_metadata`) change the CNAME or TXT verification record, so no re-verification is needed after any operation here.
