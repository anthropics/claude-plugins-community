# Check Domain Health

Read-only diagnosis of the tenant's custom domain configuration. No writes. Answers: "is my setup still working?" and "what would block me from doing X?"

This is the safe starter capability. Run it before other capabilities when the user isn't sure what's wrong or just wants a status check.

## Pre-flight: surface the active tenant

Even though this capability is read-only, the data the user sees depends entirely on which tenant the Auth0 CLI is pointed at. Show it explicitly so the report header is unambiguous.

```bash
auth0 tenants list
```

Surface the active tenant to the user and confirm it's the one they want checked. If it's wrong, have them run `auth0 tenants use <tenant-name>`, then proceed. Include the tenant name in the final health report so the output is self-describing.

## Checks (run in parallel)

### 1. List custom domains on the tenant

```bash
auth0 api get "custom-domains"
```

Pull for each: `domain`, `custom_domain_id`, `status`, `type`, `primary`.

### 2. Fetch the tenant default

```bash
auth0 api get "tenants/settings"
```

Read `default_custom_domain_id`. Cross-reference against the domain list from check 1.

### 3. For each domain, compare DNS to expected

For each domain in the list, dig the CNAME and compare to the expected verification record. The expected value is in `verification.methods[0].record` on each domain object.

```bash
dig +short CNAME login.example.com
```

For self-managed domains, the expected record is a TXT, not a CNAME:

```bash
dig +short TXT login.example.com
```

### 4. Check NS resolution from an external resolver

Cross-check the user's local resolver against a public resolver to catch propagation lag:

```bash
dig +short @8.8.8.8 CNAME login.example.com
```

Mismatch between local and external means propagation is in progress; the domain may show `ready` in Auth0 but some clients won't yet see the right record.

### 5. Reachability and TLS certificate probe

`status: ready` in Auth0 confirms Auth0's side is wired up, but it doesn't confirm the domain is reachable from the public internet right now, or that the TLS handshake succeeds. A proxy/CDN misconfiguration, a firewall rule, or an expired cert on a self-managed setup will all pass check 3 and still be broken for end users.

For each `ready` domain, probe HTTPS:

```bash
curl -sS -o /dev/null -w "%{http_code} %{ssl_verify_result}\n" \
  --max-time 10 "https://login.example.com/"
```

Expected: a `200`, `302`, or `404` with `ssl_verify_result: 0`. Any of these confirms TLS handshake succeeded and Auth0 responded. Problem signals:
- **Timeout** or connection refused: a proxy/firewall is blocking, or the DNS points somewhere Auth0 no longer serves.
- **`ssl_verify_result` non-zero, or curl returns SSL error**: cert is expired, mismatched, or self-signed. On Auth0-managed, this usually means renewal has failed — check 6 below.
- **Response from a non-Auth0 origin** (e.g., a WAF block page, a "site not found" page from a CDN): the CNAME is correct but an in-path proxy is intercepting.

Also fetch the cert's expiry so the report can surface upcoming renewals or detect failed renewals:

```bash
echo | openssl s_client -connect login.example.com:443 -servername login.example.com 2>/dev/null \
  | openssl x509 -noout -dates
```

Report `notAfter`. For Auth0-managed certs, normal lifecycle is ~90 days; a `notAfter` within 14 days on a `ready` domain that looks DNS-healthy is normal (renewal is imminent). A `notAfter` in the past or within 48 hours with no sign of a new cert is a renewal failure — flag it.

### 6. Flag silent renewal-breakers on `ready` domains

A domain that's `ready` today can still fail certificate renewal in the next ~3-month cycle if DNS was touched after initial verification. The signals for this are already captured in checks 3 and 5; promote them to a distinct renewal-risk line in the report when present:

- DNS mismatch on a `ready` domain (check 3 ✗): the record was removed or changed post-verification. Renewal will fail at the next cycle.
- Proxied / orange-cloud CNAME on a `ready` domain: the live record looks like a CDN hostname instead of `edge.tenants.auth0.com`. Detect by inspecting the CNAME resolution chain.
- Cert `notAfter` in the past on a `ready` domain (check 5): renewal has already failed.

These cases are not reachable-today failures but they will page someone in a future on-call shift; the health check is the right place to surface them early.

### 7. Credit-card-on-file note (Free tier only)

Do not probe speculatively by attempting a create. If the tenant has zero custom domains and the user is asking whether adding one will work, mention the Free-tier requirement in the output report:

```text
Note: Free-tier tenants need a credit card on file at
Dashboard → Tenant Settings → Billing to create custom domains. The card is
not charged. If custom domain creation returns 403, this is usually the cause.
```

## Output format

Structured checklist with pass/fail/warn per item. Lean on visual contrast (✓, ✗, ⚠) and keep the output scannable:

```text
Tenant: acme-prod

Custom domains (3):

  login.example.com                 ✓ ready
    DNS match                       ✓ CNAME → tenant.edge.tenants.auth0.com
    Reachability (HTTPS)            ✓ 302, TLS valid
    Cert expires                    2026-08-03 (90 days)
    Certificate type                Auth0-managed
    Default for tenant              ✓ YES

  login-eu.example.com              ⚠ ready, but renewal at risk
    DNS match                       ✗ CNAME now points to a Cloudflare proxy
    Reachability (HTTPS)            ✓ 302, TLS valid
    Cert expires                    2026-06-10 (36 days)
    Certificate type                Auth0-managed
    Default for tenant              no
    ⚠ DNS was changed after verification; next renewal will fail

  login-legacy.example.com          ⚠ pending_verification
    DNS match                       ✗ no CNAME found at login-legacy.example.com
    Reachability (HTTPS)            ✗ connection refused
    Certificate type                Self-managed
    Default for tenant              no

Tenant settings:
  Default custom domain             ✓ login.example.com

Summary:
  • 1 of 3 domains fully healthy
  • login-eu.example.com: DNS change will break the next cert renewal → run Troubleshoot verification to restore the record
  • login-legacy.example.com: never finished verifying → run Troubleshoot verification
```

## Interpreting results

- **`ready` + DNS ✓ + reachable ✓ + cert valid**: healthy. Auth0-managed renewal will happen on schedule.
- **`ready` + DNS ✗ (any reason: missing, proxied, flattened)**: reachable today, but Auth0 can't re-validate at the next renewal cycle (~90 days). Flag as renewal-at-risk; route to Troubleshoot verification to restore the record now.
- **`ready` + DNS ✓ + reachable ✗**: Auth0's side is correct but something in-path is blocking (firewall, WAF, proxy misroute). Look at the curl error and the CNAME resolution chain to pinpoint.
- **`ready` + cert `notAfter` in the past**: renewal has already failed. This is an active outage for TLS clients, even if `status` still reads `ready`. Route to Troubleshoot verification; contact support if the record is correct and cert still won't renew.
- **`pending_verification` + DNS ✓**: record is correct but Auth0 hasn't finished verifying, or verification was never triggered. If it's been more than a few minutes, route to Troubleshoot verification.
- **`pending_verification` + DNS ✗**: record is missing. Route to Set up a custom domain (from the "write the record" step) to put it back, then verify.
- **`disabled`**: rare; indicates an internal state mismatch. Usually requires support.

## When to recommend other capabilities

Use the health check output to point the user to the next capability:

- DNS mismatch or verification failure → the Troubleshoot verification flow
- `ready` domain flagged renewal-at-risk (DNS changed post-verification, proxied CNAME, cert nearing/past expiry) → the Troubleshoot verification flow, now rather than later
- Reachability ✗ despite correct DNS → the Troubleshoot verification flow; start from in-path proxies and firewalls
- No default set and multiple domains → the Manage existing domains flow
- Domains in `pending_verification` past normal window → the Troubleshoot verification flow
- User wants to add another domain or clean up an unused one → the Set up a custom domain flow or the Remove a custom domain flow
