# Remove a Custom Domain

Delete a custom domain from Auth0 and clean up the CNAME record in the user's DNS. Destructive; always confirm before executing and warn about dependent systems.

## Inputs

- The domain name or `custom_domain_id` to remove.
- Tenant context.

## Pre-flight: confirm the active tenant

Delete is irreversible. Before anything else, confirm the Auth0 CLI is pointed at the intended tenant.

```bash
auth0 tenants list
```

Show the active tenant to the user and require explicit confirmation ("about to delete from `acme-prod`; confirm?"). If wrong, stop and have the user run `auth0 tenants use <tenant-name>`, then re-confirm. Deleting from the wrong tenant is not recoverable; the domain and its certificate state are gone.

## Safety checks before deleting

Run these in parallel. Report every flag that comes up; let the user confirm with full awareness.

### 1. Is this the default custom domain?

```bash
auth0 api get "tenants/settings"
```

If `default_custom_domain_id` matches the domain being deleted, warn:

```text
login.example.com is the default custom domain for this tenant. Deleting it
means notification-triggering Management API calls will route through
your-tenant.auth0.com until you set a new default via the Manage existing domains flow.
```

The user can proceed anyway, but they should plan to set a new default right after.

### 2. Is this the only custom domain?

```bash
auth0 api get "custom-domains"
```

If the list has only this one domain, warn:

```text
This is the only custom domain on the tenant. After deletion, all traffic will
use your-tenant.auth0.com. Apps and SDKs currently pointing at
login.example.com will start failing with iss claim mismatches.
```

### 3. Are applications or tenant settings referencing this domain?

There is no single Management API call that surfaces "everything that references this domain." What we can scan is partial; what we can't scan has to be hand-checked. Default behavior: **do not scan**. Show the user the full list of places a reference could live, and let them choose.

#### Show the reference-sites list and ask

Output a complete inventory of surfaces the domain could appear on, grouped by whether the scan can reach them. Then ask which scan tier to run.

```text
Before deleting login.example.com, here's where a reference to it could live:

Reachable via Auth0 Management API:
  • Application client configurations (callbacks, logout URLs, web origins, allowed origins, initiate_login_uri, client_metadata)
  • Tenant settings (support_url, default_redirection_uri, change_password.html, guardian_mfa_page.html, error_page.url)
  • Email provider default "from" address
  • Email template "from" and "body" fields (per-template overrides)
  • Actions code
  • Rules code (legacy)
  • Hooks code (legacy)
  • Branding page templates (Liquid)
  • Organizations (branding logo URLs)
  • Connections (options: login URLs, custom scripts, enterprise IdP URLs)
  • Resource server identifiers
  • Log stream webhook URLs
  • Prompt / ACUL custom text

Not reachable by the skill (you'll need to check these yourself):
  • SDK configurations in your applications (domain / issuerBaseURL)
  • JWT validators in backend APIs (iss claim allowlist)
  • SAML SP metadata saved at any service provider that federates here
  • Terraform / IaC / CI-CD config
  • External tools (monitoring, Zapier, Slack bots, scripts)
  • Email DNS records (SPF / DKIM / DMARC) if the from address embeds the custom domain

Three options:
  1. Skip the scan (I've already checked; proceed to confirm)
  2. Quick scan (clients, tenant settings, email provider + templates — ~1-3s on typical tenants, ~5-10s on large enterprise tenants)
  3. Deep scan (everything in the Reachable list above — slower, noisier, more false positives)

Which one?
```

Wait for the user to choose. Default posture: assume option 1 unless the user asks for a scan — it's their audit to run.

#### Option 1: skip

Proceed to **Confirm**.

#### Option 2: quick scan (tier 1)

Fire these in parallel. Stop and report as soon as they all return.

| Call | Field(s) to grep for the custom domain |
|---|---|
| `GET /clients` (paginated, fan out across pages in parallel once page 1 reveals total) | `callbacks`, `allowed_logout_urls`, `web_origins`, `allowed_origins`, `initiate_login_uri`, JSON-stringified `client_metadata` |
| `GET /tenants/settings` | `support_url`, `default_redirection_uri`, `change_password.html`, `guardian_mfa_page.html`, `error_page.url` |
| `GET /emails/provider` | `default_from_address` |
| `GET /email-templates/{name}` × 11 (`verify_email`, `verify_email_by_code`, `reset_email`, `reset_email_by_code`, `welcome_email`, `blocked_account`, `stolen_credentials`, `enrollment_email`, `mfa_oob_code`, `user_invitation`, `async_approval`) | On responses that return 200 AND `enabled: true`: grep `from` and `body`. Drop 404s (never customized) and `enabled: false` (won't send). |

**Parallelism is required.** Sequential, this is 15+ calls and noticeably slow. With parallel fan-out (e.g., `xargs -P`, shell `&` + `wait`, or the agent firing tool calls in one turn) the total is bounded by the slowest single call.

After the scan, report hits with specific locations, then always append the reminder:

```text
Quick scan found {N} references:
  • Client "Web App"                      callbacks[2]
  • Client "Mobile App"                   allowed_logout_urls[0]
  • Email template "reset_email"          from: "no-reply@login.example.com"
  • Tenant setting                        support_url

Note: this was the quick scan. Still unchecked in Auth0:
  Actions, Rules, Hooks, Branding templates, Organizations, Connection options,
  Resource server identifiers, Log stream webhooks, Prompt / ACUL custom text.
Run the deep scan if you want me to check those, or proceed if you've already audited them.

And regardless of scan depth, check these yourself (not reachable via API):
  • SDK configs (domain / issuerBaseURL)
  • Backend JWT validators
  • SAML SP metadata
  • Terraform / IaC / CI-CD
  • Third-party integrations
  • Email DNS (SPF / DKIM / DMARC if from address embeds this domain)
```

#### Option 3: deep scan (tier 2)

Fire everything in the Reachable list above in parallel, in addition to tier 1:

| Call | Field(s) to grep |
|---|---|
| `GET /actions/actions` (paginated) | `code` |
| `GET /rules` (legacy; skip cleanly if empty) | `script` |
| `GET /hooks` (legacy; skip cleanly if empty) | `script` |
| `GET /branding/templates/universal-login` | `template` (Liquid HTML) |
| `GET /organizations` (paginated) + `GET /organizations/{id}/branding` per org | `logo_url`, `colors`, `branding.logo_url` |
| `GET /connections` (paginated) | `options` JSON stringified |
| `GET /resource-servers` (paginated) | `identifier` |
| `GET /log-streams` | sink URLs (`sink.httpEndpoint`, webhook URLs) |
| `GET /prompts/{prompt}/custom-text/{lang}` for configured prompts | body text fields |

Time budget the deep scan to ~30s; if it's still running past that, surface partial results with a note that scanning timed out on {list of pending endpoints}.

Expect false positives — string matches inside unrelated JSON fields (user-chosen connection names, org slugs, etc.). Report the hit with the containing JSON path so the user can judge.

After the deep scan, always append the "not reachable via API" reminder from option 2. The scan is never complete; the user still has to check the external surfaces themselves.

## Confirm

Show the full impact and ask for explicit yes. Include the current CNAME target value (pulled from `verification.methods[0].record`) so the user can confirm they're deleting the right record. Reflect the scan tier they chose in step 3:

```text
Ready to delete login.example.com from tenant acme-prod.

Current record:
  CNAME login.example.com → tenant.edge.tenants.auth0.com

This will:
  • Remove the custom domain from Auth0 (irreversible)
  • Invalidate the Auth0-managed certificate
  • Delete the CNAME from DNS (via Route 53 / Cloudflare / etc.; see below)
  • [if default] unset the tenant's default custom domain

Flags:
  • This is the tenant's default custom domain
  • {one of}
      — No scan was run; you confirmed you've already audited.
      — Quick scan found 3 references: [list]. Deeper surfaces and external
        systems not checked.
      — Deep scan found 5 references: [list]. External systems not checked.

Proceed? [yes / no]
```

If the scan found references, pause here and let the user decide whether to fix them first or accept the breakage. A "yes" after seeing scan hits is explicit acknowledgement; do not nag further.

## Delete in Auth0

```bash
auth0 api delete "custom-domains/<domainId>" --force
```

`--force` is important: without it the CLI prints its own confirmation prompt, which duplicates the skill's confirmation and hangs in non-interactive contexts. The skill has already obtained explicit yes from the user, so pass `--force`.

Note the current CNAME target value before deletion; after deletion, the Management API no longer returns it, so if the user wants to recreate later they'd need the new value from a fresh create.

## Clean up the DNS record

**Always attempt automated cleanup first.** Detect the provider from the root domain's NS records and route by tier, same as the Set up a custom domain flow. The skill should do the cleanup for the user, not ask the user to do it manually, whenever the provider tier supports automation and the required credentials are present.

### Automated path (preferred)

- **Tier 1 Cloudflare (via MCP)**: If the Cloudflare MCP is connected, `search("dns records")` then `execute()` a script that calls `cf.dns.records.delete(record_id)` for the CNAME at the target name. No user action needed. Full mechanics: [providers/cloudflare.md](providers/cloudflare.md).
- **Tier 2 Route 53**: If AWS credentials are configured (`aws sts get-caller-identity` succeeds), run `aws route53 change-resource-record-sets` with action `DELETE` (requires the full record set to match). Use `list-resource-record-sets` first to get the exact current value, then poll `get-change` until `INSYNC`. No user action needed. Full mechanics including the exact-match DELETE gotcha: [providers/route53.md](providers/route53.md#delete-the-cname-record-the-remove-a-custom-domain-flow).
- **Tier 3 Azure DNS**: If the Azure CLI is signed in (`az account show` succeeds), run `az network dns record-set cname delete --resource-group my-rg --zone-name example.com --name login --yes`. No user action needed. Full mechanics: [providers/azure-dns.md](providers/azure-dns.md).

Open only the sub-file matching the detected provider; don't load all three.

### Manual fallback

Drop to manual guidance only when automation isn't possible — Tier 4 providers (GoDaddy, Namecheap, Hover, etc.), or Tiers 1-3 where the required credentials / MCP aren't available and the user can't authorize them right now. In that case, give clear step-by-step directions:

```text
Couldn't remove the DNS CNAME automatically ({reason: no Cloudflare MCP connection /
no AWS credentials / etc.}). Remove it manually:

1. Go to: {dashboard deep-link for the detected provider}
2. Find the CNAME record:
     Name:  login.example.com
     Value: tenant.edge.tenants.auth0.com
3. Delete it.

Reply 'done' when removed so I can confirm the DNS record is gone, or 'skip' if
you want to leave it in place (harmless but clutters your zone).
```

Use the provider cheat-sheet in [providers/manual.md](providers/manual.md#per-provider-cheat-sheet) for the right deep-link and UI labels. On "done", run `dig +short CNAME login.example.com` to verify the record is gone; warn the user if it still resolves (propagation can take a few minutes).

### Why automate by default

The CNAME is now orphaned: it points at an Auth0 edge hostname that no longer serves the user's domain. Leaving it in place is harmless but clutters the zone and can cause confusion later. Auto-cleanup is the right default; manual is an exception path.

## If the user is keeping the domain but switching tenants

Different flow; don't run this capability. They should:
1. Delete from the original tenant (Auth0 won't let the same domain live on two tenants).
2. Leave the DNS record in place.
3. Create the domain on the new tenant (the Set up a custom domain flow). The CNAME target value will change; they'll need to update the existing DNS record rather than add a new one.

## Post-delete reminder

After successful deletion, tell the user:

```text
Deleted login.example.com from Auth0.
DNS CNAME removed via {provider}.

Next steps (outside this skill's scope):
  • Update SDK `domain` / `issuerBaseURL` config back to your-tenant.auth0.com
    in any app that was pointing at login.example.com
  • Update application callback URLs that reference the old custom domain
  • [if was default] set a new default custom domain via the Manage existing domains flow
```
