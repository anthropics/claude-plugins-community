# Set Up a Custom Domain

End-to-end provisioning: create the domain in Auth0, write the CNAME into the user's DNS provider, verify ownership, and report what to update in their apps. Handles both the first custom domain on a tenant and adding another one to a tenant with MCD already enabled.

## Gather inputs

Ask questions one at a time as plain conversational text. Do not present all inputs at once or use structured UI widgets. Sequence:

1. **Domain hostname**: Ask directly — "What hostname do you want to set up? (e.g., `login.example.com`)" — and wait for the reply.

2. **Certificate type**: Default to `auth0_managed_certs` silently. Only ask if the user has given a signal they need self-managed (Enterprise reverse-proxy setup). Mention once that type is fixed at create time.

3. **Passkey / RPID plan**: Skip this question entirely. For subdomains, include `relying_party_identifier` (eTLD+1) speculatively in the create call — it's almost always the right default and there is no probe endpoint to check the feature flag in advance. If the create returns `operation_not_supported`, retry without it and tell the user: "The `relying_party_identifier` feature isn't enabled on this tenant. The domain was created without it. Contact Auth0 support to enable the flag; RPID can be set via PATCH once it's on." For root-domain custom domains, omit `relying_party_identifier` entirely — passkeys bind to the root automatically.

4. **Reverse proxy**: Ask only if there's a signal the tenant is behind a proxy. "Is Auth0 behind a reverse proxy (Cloudflare, CloudFront, Azure Front Door)? If so, I'll set the client IP header so rate limiting sees the real IP." Default to no header.

5. **TLS policy**: Do not ask. Default to `recommended` silently unless the user raises a compliance requirement.

6. **Tenant confirmation**: Run `auth0 tenants list`, show the active tenant, and ask for confirmation before creating. This is the one place a yes/no confirmation is required.

## Create the domain in Auth0

Minimal create (Auth0-managed certs, defaults everywhere):

```bash
auth0 api post "custom-domains" --data '{
  "domain": "login.example.com",
  "type": "auth0_managed_certs"
}'
```

Full-featured create with optional fields (omit any that don't apply):

```bash
auth0 api post "custom-domains" --data '{
  "domain": "login.example.com",
  "type": "auth0_managed_certs",
  "verification_method": "txt",
  "tls_policy": "recommended",
  "custom_client_ip_header": "cf-connecting-ip",
  "relying_party_identifier": "example.com",
  "domain_metadata": {
    "region": "us-east",
    "brand": "acme"
  }
}'
```

Notes on the optional fields:
- `verification_method`: default is derived from `type` (CNAME for Auth0-managed, TXT for self-managed). Only set it if explicitly overriding.
- `tls_policy`: default `recommended`; no reason to set unless compliance requires.
- `custom_client_ip_header`: one of `true-client-ip`, `cf-connecting-ip`, `x-forwarded-for`, `x-azure-clientip`. Match the header the proxy in front of Auth0 emits.
- `relying_party_identifier`: set when the custom domain is a subdomain but passkeys should bind to the parent domain.
- `domain_metadata`: up to 10 key-value pairs (keys and values ≤ 255 chars); surfaces in Actions.

The response contains `custom_domain_id`, `status: "pending_verification"`, and `verification.methods[0].record`: the CNAME value to put in DNS. Save these.

**If the API returns 400 with `operation_not_supported` on `relying_party_identifier`**: the feature flag is not enabled on this tenant. Retry the create without `relying_party_identifier`, then tell the user: "The `relying_party_identifier` feature isn't enabled on this tenant. Domain created without it. Contact Auth0 support to enable the flag; RPID can be set via PATCH once it's on."

**If the API returns 403**: the tenant is a Free tenant without a credit card on file. Direct the user to **Dashboard → Tenant Settings → Billing** (or the Teams section for Teams-managed tenants) to add a card, then retry. The card is not charged. This is the correct diagnosis on Free tier; do not suggest a plan upgrade.

**If the API returns 409**: the domain already exists on this or another tenant. `auth0 api get "custom-domains"` to list existing. If it's already on this tenant and just needs verification, skip to the verify step below with the existing `custom_domain_id`.

See [examples.md](examples.md) for curl, node-auth0, and auth0-python code patterns.

## Detect the DNS provider and route to a tier

```bash
dig +short NS example.com
```

Match the NS pattern against the table in [providers.md](providers.md#ns-pattern-to-provider-mapping) to select a tier, then open **only** the matching sub-file:

- **Tier 1 Cloudflare** → [providers/cloudflare.md](providers/cloudflare.md) (full automation via Cloudflare MCP)
- **Tier 2 AWS Route 53** → [providers/route53.md](providers/route53.md) (assisted via AWS CLI)
- **Tier 3 Azure DNS** → [providers/azure-dns.md](providers/azure-dns.md) (assisted via Azure CLI)
- **Tier 4 other** → [providers/manual.md](providers/manual.md) (guided manual record entry)

Each sub-file is self-contained (plan requirements, pre-flight, create, error handling, fallback). Don't load every tier — load only the one that matches the detected NS pattern. Return here for the verify step once the record is written.

## Check for an existing record at the target name

Before writing, check what's already there:

```bash
dig +short CNAME login.example.com
```

Three outcomes:
1. **No record**: proceed with the write.
2. **Record matches the expected value**: skip the write, go straight to verify.
3. **Record exists with a different value**: confirm with the user before overwriting. Show both values. On Tier 2 (Route 53) the `UPSERT` action will overwrite silently, so the confirmation has to happen in the skill, not the CLI.

## Write the CNAME record

Execute the tier-specific flow from the sub-file you opened above. For Tiers 2 and 3, wait for the provider to report propagation complete (Route 53: `INSYNC`; Azure: proceed after ~30s) before triggering Auth0 verification. For Tier 4, wait for the user to reply "done."

## Trigger Auth0 verification

```bash
auth0 api post "custom-domains/<domainId>/verify"
```

## Poll until ready

Poll `GET /api/v2/custom-domains/<domainId>` with backoff: 5s, 10s, 20s, 30s, 60s, 60s... up to ~10 minutes total. Stop when `status` becomes `ready`.

If the polling window expires with status still `pending_verification`: route to the **Troubleshoot verification** flow rather than retrying blindly.

## Report next steps

On success, tell the user what they need to update in their applications:

```text
Custom domain login.example.com is verified and ready.

Next steps (outside this skill's scope):
  • SDK config: change the `domain` / `issuerBaseURL` value to login.example.com
    in every application SDK
  • Application callback URLs: update any URLs that reference the old tenant
    domain
  • Passkey rpId: if using passkeys, confirm rpId matches the eTLD+1 of the
    custom domain
  • SAML / WS-Fed metadata URLs: regenerate and redistribute

Full guide: https://auth0.com/docs/customize/custom-domains/configure-features-to-use-custom-domains
```

If the tenant now has multiple custom domains for the first time, mention that they may want to set a default via the Manage existing domains flow.

## MCD: adding a domain to a tenant that already has one

The flow above is identical whether this is the tenant's first custom domain or the Nth. A few things to mention when MCD is in play:

- The new domain gets its own `custom_domain_id`, CNAME verification record, and certificate lifecycle.
- Consider setting a default custom domain after adding the second domain (the Manage existing domains flow). Without a default, notification-triggering Management API calls route through the tenant domain unless the caller sends the `auth0-custom-domain` header. See [advanced.md](advanced.md#the-auth0-custom-domain-header).
- MCD is Enterprise-only with a base of 20 domains per tenant. If the user is on a non-Enterprise plan, creating a second domain returns a 403 with a different error than the Free-tier CC case; surface the full error body so the user knows which limit they hit.

## Edge cases to handle during setup

- **Private hosted zone (Route 53)**: if `list-hosted-zones-by-name` returns a private zone, fall back to Tier 4; Auth0 verification needs a public zone.
- **Apex vs subdomain**: the CNAME always goes into the zone of the root domain, at the subdomain name. If the user asked for a custom domain at the apex (e.g., `example.com` itself), DNS doesn't permit a real CNAME at the apex; suggest a subdomain instead or use ALIAS/ANAME records where supported.
- **Shared parent zone with delegation**: if the apex is delegated to a different provider than the subdomain, check the NS records for the subdomain specifically, not just the root.
