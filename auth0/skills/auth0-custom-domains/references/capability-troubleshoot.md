# Troubleshoot Verification

A custom domain that's stuck in `pending_verification`, or verification that keeps failing. Walks a diagnostic ladder; fixes what's fixable; falls back to waiting or opening a support ticket when nothing else works.

## Inputs

- The `custom_domain_id` or the domain name (look up the ID via `auth0 api get "custom-domains"` if only the name is known).
- Confirmation that the user has already gone through the Set up a custom domain flow at some point (if not, route them to the Set up a custom domain flow first).

## Pre-flight: surface the active tenant

Before reading domain state or retrying verification, show the active Auth0 CLI tenant to the user. The CLI is single-tenant, and troubleshooting a domain on the wrong tenant will produce confusing results (404 on the ID, or a different domain's verification state).

```bash
auth0 tenants list
```

Surface the active tenant and ask the user to confirm it is the one hosting the broken domain. If it's wrong, stop and have them run `auth0 tenants use <tenant-name>`, then re-confirm before loading state. This applies even for read-only diagnostic calls — wrong-tenant reads waste time and mislead; the retry-verify call at the end is an actual write that must hit the right tenant.

## Get the current state from Auth0

```bash
auth0 api get "custom-domains/<domainId>"
```

From the response, pull:
- `status` (should say `pending_verification` or `disabled`)
- `verification.methods[0].record` (the expected CNAME value)
- `verification.methods[0].domain` (the name the record should sit at, typically the custom domain itself)
- `type` (Auth0-managed vs self-managed; if self-managed, the verification is TXT not CNAME)

## Diagnostic ladder

Run these checks in order. Stop at the first one that identifies a problem; fix it; retry verification; if still stuck, continue to the next check.

### 1. Compare actual DNS to expected

```bash
dig +short CNAME login.example.com
```

Compare the result to `verification.methods[0].record`. Common mismatches:

- **Typo**: one character off. Fix in the DNS provider and wait for propagation.
- **Trailing dot difference**: `tenant.edge.tenants.auth0.com.` vs `tenant.edge.tenants.auth0.com`. Both are technically valid in DNS but some registrars are picky. Try removing the trailing dot if present.
- **Empty result**: no CNAME exists at the target name. The record was never added or was deleted. Route back to the Set up a custom domain flow from the "write the CNAME" step.
- **Completely different value**: another record exists at that name (maybe pointing to a previous provider or an internal service). Confirm with user before replacing.

### 2. Check for DNS proxy

If the result of `dig` looks like a generic CDN hostname (Cloudflare, Fastly, Akamai) rather than the `edge.tenants.auth0.com` pattern, the record is likely behind a proxy:

- **Cloudflare orange cloud**: In the Cloudflare dashboard, the record must be DNS-only (grey cloud), not proxied (orange). Tell the user to toggle it off. Or, if Cloudflare MCP is connected, update `proxied: false` directly.
- **Other proxies**: Any CDN or reverse proxy layered on the CNAME will break Auth0 verification and certificate renewal. The record needs a direct DNS CNAME pointing at the Auth0 edge hostname.

### 3. Check for CNAME flattening

Some providers (Cloudflare, Gandi LiveDNS, others) optionally flatten CNAMEs at the apex or across records. Flattening rewrites the CNAME to A/AAAA records at resolution time, which breaks what Auth0 sees.

- Ask the user to check their zone settings for any "CNAME flattening" or "CNAME at apex" option.
- This is zone-level, not per-record, so the user has to toggle it at the zone.

### 4. Check for conflicting record types

Per DNS RFC, a CNAME cannot coexist with other record types at the same name. If there's an A, AAAA, MX, or TXT record at the target name, the CNAME may be silently dropped or fail to create:

```bash
dig login.example.com ANY
```

If other records are present, either delete them (if not in use) or pick a different subdomain for the custom domain.

### 5. Check propagation state

Fresh records can take 5-60 minutes to propagate. Cross-check with a non-local resolver:

```bash
dig +short @8.8.8.8 CNAME login.example.com
dig +short @1.1.1.1 CNAME login.example.com
```

If these return the correct value but the user's local resolver doesn't, propagation is still in progress. Wait 15-30 minutes and retry verification.

### 6. Check for private-zone issue (Route 53)

On AWS Route 53, private hosted zones are resolvable only from within a VPC. If the user's root domain is managed in a private hosted zone, Auth0 can't see the record from the public internet:

```bash
aws route53 list-hosted-zones-by-name --dns-name example.com --max-items 5
```

Look for a `PrivateZone: true` entry. If that's the zone the record went into, the fix is to move the record to a public zone or delegate the subdomain to a public zone.

### 7. Retry verification

After applying a fix, trigger verification:

```bash
auth0 api post "custom-domains/<domainId>/verify"
```

Then poll for up to ~5 minutes:

```bash
auth0 api get "custom-domains/<domainId>"
```

## What not to do

- **Do not delete and recreate the domain.** This resets the provisioning state and can cause a service interruption for tokens already issued. If the user mentions they've already done this once or twice, ask them to stop and wait.
- **Do not retry verification in a tight loop.** Auth0 rate-limits verification attempts. The 5-10-20-30-60 second backoff is the right pattern.

## When to open a support ticket

Recommend the user file a support ticket if:
- The CNAME is correct in DNS from multiple external resolvers, not proxied, not flattened, and verification has been failing for 24+ hours
- Multiple create/delete cycles have been performed (the domain may be in a state only support can resolve)
- The domain status is `disabled` rather than `pending_verification` (rare; indicates an internal state mismatch)

For general guidance beyond this ladder, see [advanced.md](advanced.md#verification-troubleshooting).
