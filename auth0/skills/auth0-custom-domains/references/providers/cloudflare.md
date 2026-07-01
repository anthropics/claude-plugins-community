# Cloudflare (Tier 1: Full Automation)

Cloudflare publishes an official MCP server at `https://mcp.cloudflare.com/mcp` with OAuth browser auth. The server exposes two tools (`search()` and `execute()`) and runs generated JavaScript against a sandboxed Cloudflare API client.

## Plan requirements

DNS management on Cloudflare is **available on every plan including Free**. The `https://mcp.cloudflare.com/mcp` server wraps the same Cloudflare API and needs no paid Cloudflare plan for DNS CRUD. Cloudflare's GitHub README hedges that "some features may require a paid Workers plan"; that applies to MCP features tied to paid products (Workers deploys, Containers, AI Gateway), not DNS.

Free-plan caveats to surface to the user:
- Zones created after September 2024 cap at **200 DNS records per zone**. Auth0's CNAME counts as one; most hobby zones are nowhere near this.
- Free plan minimum TTL is 60 seconds (30 on Enterprise). `ttl: 1` uses Cloudflare's automatic TTL and works on Free.
- Free plan does not allow API tokens with Client IP Address Filtering. The MCP's OAuth flow avoids this.

## Pre-flight check

Confirm the Cloudflare MCP is connected to the user's Claude Code session. If not:

```text
The Cloudflare MCP server isn't connected. Add it with:

  claude mcp add --transport http cloudflare https://mcp.cloudflare.com/mcp

Then authorize in the browser when Claude prompts you.
```

## Creating the CNAME record

Because Cloudflare's MCP exposes only `search()` and `execute()`, the skill prompts the LLM to generate a small script rather than calling a named tool. The pattern:

1. `search("dns records")` to locate the endpoint
2. `execute()` to run a script that finds the zone ID then creates the record

Script pattern for `execute()`. **Before passing to `execute()`, substitute the three placeholders with real values**: `ROOT_DOMAIN` (e.g., `example.com`), `CUSTOM_DOMAIN` (e.g., `login.example.com`), and `CNAME_TARGET` (the `verification.methods[0].record` value returned by `POST /custom-domains`, NOT the literal string below).

```javascript
// Find the zone ID for the root domain
const zones = await cf.zones.list({ name: "ROOT_DOMAIN" });
if (zones.result.length === 0) {
  throw new Error("Zone ROOT_DOMAIN not found in this Cloudflare account");
}
const zoneId = zones.result[0].id;

// Check for existing record at the target name
const existing = await cf.dns.records.list({
  zone_id: zoneId,
  name: "CUSTOM_DOMAIN",
  type: "CNAME",
});

// Create the CNAME (or update if one already exists; confirm with user first)
if (existing.result.length === 0) {
  return await cf.dns.records.create({
    zone_id: zoneId,
    type: "CNAME",
    name: "CUSTOM_DOMAIN",
    content: "CNAME_TARGET",  // must match verification.methods[0].record exactly
    proxied: false,  // critical: Auth0 verification fails on proxied records
    ttl: 1,  // 1 = automatic, Cloudflare default
  });
} else {
  // Present the existing value and confirm overwrite before calling update()
}
```

## Key constraints

- `proxied` must be `false`. A proxied (orange-cloud) CNAME breaks Auth0 verification and Auth0-managed certificates.
- Minimum TTL is 60s on standard zones, 30s on Enterprise. `ttl: 1` uses Cloudflare's automatic TTL.
- The authenticated token needs `DNS:Edit` scope on the target zone. OAuth flow grants this by default when the user authorizes.
- API tokens with Client IP Address Filtering are not supported by the MCP.

## Fallback

If the Cloudflare MCP can't be used (auth failure, zone not in account, unexpected error), drop to [manual guided](manual.md) with Cloudflare dashboard deep-link:
`https://dash.cloudflare.com/?to=/:account/:zone/dns/records` (the user needs to know their account and zone; a simpler fallback is `https://dash.cloudflare.com/` and instruct them to navigate).
