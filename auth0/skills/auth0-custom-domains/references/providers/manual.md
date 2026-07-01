# Manual Guided (Tier 4: Everyone Else)

For all other providers, the skill outputs a copy-pasteable record block and provider-specific instructions.

## Record block to output

Show exactly (substitute the Host and Value with the actual values returned by `POST /api/v2/custom-domains` — the block below uses `login` and `tenant.edge.tenants.auth0.com` only as placeholders):

```text
Record type: CNAME
Host / Name: login              (the subdomain portion only, not the full FQDN)
Value / Points to: tenant.edge.tenants.auth0.com
TTL: 300 (or provider default)
Proxy / Orange cloud: OFF / DNS-only
```

Note the "Host" formatting: most providers expect just the subdomain (`login`), but a few expect the full FQDN (`login.example.com`). Call this out in the per-provider instructions below.

## Per-provider cheat sheet

All providers below use the same record values (type CNAME, host is the subdomain only, value is the Auth0-provided CNAME target). Differences are dashboard URL, label naming, and navigation path.

| Provider | Dashboard URL (substitute the root domain) | UI labels (host, value) | Navigation hint |
|---|---|---|---|
| GoDaddy | `https://dcc.godaddy.com/manage/{domain}/dns` | Name, Value | My Products → DNS → Add New Record |
| Namecheap | `https://ap.www.namecheap.com/domains/domaincontrolpanel/{domain}/advancedns` | Host, Value | Domain List → Manage → Advanced DNS → Add New Record |
| Hover | `https://www.hover.com/control_panel/domain/{domain}/dns` | Hostname, Target Host | Account → domain → DNS → Add a Record |
| Squarespace Domains (was Google Domains) | `https://account.squarespace.com/domains/managed/{domain}/dns/dns-settings` | Host, Data | Domains → domain → DNS → DNS settings → Add record |
| Porkbun | `https://porkbun.com/account/domainsSpeedy` | Host, Answer | Domain Management → DNS Records |
| Name.com | `https://www.name.com/account/domain/details/{domain}#dns` | Host, Answer | My Domains → domain → Manage DNS Records |
| Gandi | `https://admin.gandi.net/domain/{domain}/records` | Name, Hostname | Domain → DNS Records → Add |
| Network Solutions | `https://www.networksolutions.com/my-account/` | Alias, Other Host | Manage → domain → Change Where Domain Points / Advanced DNS |
| IONOS | `https://my.ionos.com/dns` | Host name, Points to | Domains & SSL → domain → DNS |
| DreamHost | `https://panel.dreamhost.com/index.cgi?tree=domain.manage` | Name, Value | Manage Domains → DNS (for the domain) |

Common gotchas across providers:
- Host field is the subdomain only (`login`), never the full FQDN, unless the provider explicitly shows "@" or the full domain as the default.
- Some dashboards default TTL to 1 hour; 300 seconds is fine, longer is fine.
- No provider above requires a proxy toggle, but if one exists (e.g., proxied CDN), it must be off.

### Unknown provider

If NS records don't match any known pattern, output:

```text
Your DNS appears to be hosted at {nameserver domain}. Log in to that provider's
dashboard and look for "DNS", "DNS Records", "Advanced DNS", or "Zone Editor".
Add a new CNAME record with the values above.
```

## After the user confirms

Ask: "Reply 'done' when you've added the record, or 'skip' to give up for now."

On "done", proceed to Auth0 verification in SKILL.md Step 3. On "skip", save the CNAME target value and `custom_domain_id` to the conversation so they can resume later.

If verification fails, first suggest `dig CNAME login.example.com` and compare the result to the expected target.
