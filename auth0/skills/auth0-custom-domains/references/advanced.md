# Auth0 Custom Domains: Advanced Topics

Covers Multiple Custom Domains (MCD), default domain selection, the `auth0-custom-domain` header, self-managed certificates, token `iss` behavior, and verification troubleshooting.

## Multiple Custom Domains (MCD)

MCD lets a single Auth0 tenant host multiple custom domains for multi-brand or multi-region deployments. Enterprise customers get up to 20 domains per tenant out of the box; more are available via add-on SKU.

### When to use MCD

- Multi-brand: `login.brand-a.com` and `login.brand-b.com` serve different customer segments
- Multi-region: `login-us.example.com`, `login-eu.example.com` for regional isolation
- Tenant consolidation: previously running multiple tenants per brand, collapsing into one

### Adding additional domains

The skill's primary flow creates one domain. To add another, invoke the skill again with the new domain. Each domain gets its own `custom_domain_id`, its own CNAME verification record, and its own TLS certificate lifecycle.

### Default custom domain

When multiple domains are configured, one is designated the **default**. The default is used when a Management API call that triggers a notification (password reset email, verification email, etc.) is made **without** an `auth0-custom-domain` header.

Set the default. Two endpoints exist; **prefer `PATCH /custom-domains/default`** — it accepts the human-readable domain name and is the endpoint the skill uses in the Manage capability. The `tenants/settings` form is the older path, still supported, and handy when you already have the `custom_domain_id` (e.g., from a list response). Both are idempotent and produce the same result; pick whichever keeps the surrounding code simpler.

```bash
# Preferred: PATCH /custom-domains/default (pass domain name, not ID):
auth0 api patch "custom-domains/default" --data '{"domain": "login.example.com"}'

# Alternative: tenant settings endpoint (pass the custom_domain_id):
auth0 api patch "tenants/settings" --data '{"default_custom_domain_id": "cd_abc123"}'
```

The Auth0 CLI does not have a dedicated `auth0 domains default` subcommand; the API passthrough is the only way.

### The `auth0-custom-domain` header

For any Management API endpoint that triggers user-facing notifications, include the header to route through a specific custom domain:

```bash
curl --request POST \
  --url 'https://your-tenant.auth0.com/api/v2/tickets/password-change' \
  --header 'authorization: Bearer TOKEN' \
  --header 'auth0-custom-domain: login.brand-a.com' \
  --header 'content-type: application/json' \
  --data '{ "email": "user@brand-a.com" }'
```

If the header is omitted and a default domain is set, the default is used. If no default is set and no header is provided, the notification uses the tenant domain (`your-tenant.auth0.com`), which is usually not what you want.

### Migrating from single to MCD

Users with a single custom domain don't need to migrate; the domain continues to work as-is. When adding a second, consider setting an explicit default before adding it so behavior is predictable.

See [Auth0's MCD migration guide](https://auth0.com/docs/customize/custom-domains/multiple-custom-domains/migration-guide) for the full upgrade path.

## Self-Managed Certificates

Auth0-managed certificates are the default and recommended. Self-managed certificates are for enterprise customers who need to terminate TLS at their own reverse proxy.

### When self-managed is needed

- Corporate TLS policy requires specific cipher suites or cert authorities
- mTLS or pinned certificates must be used
- Integration with a specific CDN for performance or compliance

### Supported reverse proxy providers

- Cloudflare
- AWS CloudFront
- Azure CDN (Front Door)
- Google Cloud Platform Load Balancing

### Verification difference

Self-managed domains use **TXT record verification** instead of CNAME. The skill's provider playbook handles CNAME creation; for TXT records, the same tier logic applies, with the record type swapped. The provider-specific instructions in the per-provider sub-files (see the router at [providers.md](providers.md)) are identical except for the record type field.

See [Auth0-managed](https://auth0.com/docs/customize/custom-domains/auth0-managed-certificates) and [Self-managed](https://auth0.com/docs/customize/custom-domains/self-managed-certificates) for full configuration.

## Token `iss` Claim Behavior

Auth0 sets the `iss` claim on issued tokens based on the domain the token request came from:

| Request domain | `iss` value |
|----------------|-------------|
| `your-tenant.auth0.com` | `https://your-tenant.auth0.com/` |
| `login.example.com` | `https://login.example.com/` |

### Implications

- If you request a Management API token via the custom domain, you must use the custom domain for subsequent Management API calls. Using `tenant.auth0.com` with a `custom-domain` `iss` token produces `401 invalid issuer`.
- SDK configurations must use one consistent domain. Don't mix `tenant.auth0.com` in one place and `login.example.com` in another.
- JWT validation in backend APIs needs to accept the correct issuer. If you switch SDKs to a custom domain, update backend validators to match.

## Verification Troubleshooting

Custom domain verification can get stuck for several reasons. Work through these in order.

### Check the CNAME with `dig`

```bash
dig +short CNAME login.example.com
```

The output should be the exact value Auth0 returned in `verification.methods[0].record`. If the value differs, the record was added incorrectly. Compare character-by-character, watching for trailing dots, extra whitespace, or typos.

### Check for proxied records (Cloudflare orange cloud)

On Cloudflare, the record must be DNS-only (grey cloud), not proxied (orange cloud). Other proxy providers (AWS CloudFront, Fastly) can cause similar issues when placed in front of the CNAME.

### Check for CNAME flattening

Some DNS providers flatten CNAMEs at the apex or across zones. This rewrites the record Auth0 sees and breaks verification. Disable flattening for this specific record if possible.

### Check for conflicting records

Some providers won't allow a CNAME alongside other record types at the same name (per DNS RFC). If the target name has an A, AAAA, MX, or TXT record, the CNAME may be silently rejected or not propagated.

### Wait for DNS propagation

Fresh records can take 5-60 minutes to propagate across resolvers. If `dig +short @8.8.8.8 CNAME login.example.com` returns the correct value but `dig +short CNAME login.example.com` (using your local resolver) doesn't, propagation is still in progress.

### Last resort: wait 4 hours, then retry

If the record is correct in DNS but Auth0 still reports `pending_verification`:
1. Do not delete and recreate the domain. This can cause a service interruption.
2. Wait at least 4 hours.
3. Retry verification with `auth0 api post "custom-domains/<domainId>/verify"`.

### When to open a support ticket

- The CNAME is correct in DNS from multiple resolvers, not proxied, not flattened, and verification has been failing for 24+ hours
- Multiple create/delete cycles have been performed (this can put the domain in a state only support can resolve)
- The tenant shows a `disabled` status rather than `pending_verification`

## Rate Limits and Quotas

- Custom domain creates/deletes are low-frequency. No published rate limit beyond Management API defaults.
- The verify polling loop uses exponential backoff (5s, 10s, 20s, 30s, 60s...) and will not hit the 50 req/s Management API limit.
- MCD has a base entitlement of 20 domains per tenant on Enterprise. Additional capacity via add-on SKU.
