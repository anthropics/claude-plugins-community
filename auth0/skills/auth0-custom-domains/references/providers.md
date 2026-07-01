# Auth0 Custom Domains: DNS Provider Playbook (Router)

Entry point for writing the Auth0 CNAME verification record into the user's DNS provider. This file is a **router**: detect the provider from the root domain's NS records, then open only the matching tier file. Do not load every tier up-front — each tier file is self-contained.

## Provider Detection

### Lookup command

```bash
dig +short NS example.com
```

### NS pattern to provider mapping

| NS pattern | Provider | Tier | Reference |
|------------|----------|------|-----------|
| `*.ns.cloudflare.com` | Cloudflare | 1: Full automation (Cloudflare MCP) | [providers/cloudflare.md](providers/cloudflare.md) |
| `*.awsdns-*.com`, `*.awsdns-*.net`, `*.awsdns-*.org`, `*.awsdns-*.co.uk` | AWS Route 53 | 2: Assisted (AWS CLI) | [providers/route53.md](providers/route53.md) |
| `*.azure-dns.com`, `*.azure-dns.net`, `*.azure-dns.org`, `*.azure-dns.info` | Azure DNS | 3: Assisted (Azure CLI) | [providers/azure-dns.md](providers/azure-dns.md) |
| `ns*.domaincontrol.com` | GoDaddy | 4: Manual | [providers/manual.md](providers/manual.md) |
| `dns*.registrar-servers.com` | Namecheap | 4: Manual | [providers/manual.md](providers/manual.md) |
| `ns*.hover.com` | Hover | 4: Manual | [providers/manual.md](providers/manual.md) |
| `ns*.squarespacedns.com` | Squarespace Domains | 4: Manual | [providers/manual.md](providers/manual.md) |
| `curitiba.ns.porkbun.com`, `fortaleza.ns.porkbun.com`, etc. | Porkbun | 4: Manual | [providers/manual.md](providers/manual.md) |
| `ns*.name.com` | Name.com | 4: Manual | [providers/manual.md](providers/manual.md) |
| `*.gandi.net` | Gandi | 4: Manual | [providers/manual.md](providers/manual.md) |
| `ns*.worldnic.com` | Network Solutions | 4: Manual | [providers/manual.md](providers/manual.md) |
| `ns*.ui-dns.*` | IONOS | 4: Manual | [providers/manual.md](providers/manual.md) |
| `ns*.dreamhost.com` | DreamHost | 4: Manual | [providers/manual.md](providers/manual.md) |
| `ns*.googledomains.com` | Google Domains (legacy, migrated to Squarespace) | 4: Manual | [providers/manual.md](providers/manual.md) |
| Anything else | Unknown | 4: Generic manual | [providers/manual.md](providers/manual.md) |

When the NS pattern is unrecognized, fall back to generic Tier 4 instructions in [providers/manual.md](providers/manual.md) and surface the NS records to the user so they can identify the provider themselves.

## Tier summary (high-level only; details live in each tier file)

- **Tier 1 — Cloudflare**: fully automated via the Cloudflare MCP. OAuth, no plan tier required, `proxied: false` is critical. See [providers/cloudflare.md](providers/cloudflare.md).
- **Tier 2 — Route 53**: AWS CLI if credentials are configured. `UPSERT` for create, exact-match DELETE (Name, Type, TTL, Value). Poll `get-change` until `INSYNC`. See [providers/route53.md](providers/route53.md).
- **Tier 3 — Azure DNS**: Azure CLI if signed in. `az network dns record-set cname set-record`. Propagates in <30s. See [providers/azure-dns.md](providers/azure-dns.md).
- **Tier 4 — Manual**: copy-pasteable record block plus per-registrar dashboard URLs and UI-label cheat sheet. See [providers/manual.md](providers/manual.md).

## How to use this router

1. Run `dig +short NS <root-domain>` and match against the table above.
2. Open only the matching sub-file. The sub-file is self-contained — it covers plan requirements, pre-flight, create, (if applicable) delete, error handling, and fallback for that one provider.
3. If the automated tier's pre-flight fails (missing MCP, unconfigured CLI, private zone, etc.), each tier file tells you to drop to [providers/manual.md](providers/manual.md) with a provider-specific deep-link.

If you are handling the **Remove a custom domain** flow, the delete mechanics for Route 53 (exact-match requirement) live in [providers/route53.md#delete-the-cname-record-the-remove-a-custom-domain-flow](providers/route53.md#delete-the-cname-record-the-remove-a-custom-domain-flow). The other tiers delete via the same commands/UIs they create with; no special rules.
