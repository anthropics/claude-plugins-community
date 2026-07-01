# Auth0 Custom Domains: Management API Examples

cURL patterns for the Auth0 API calls the skill makes (create the custom domain, trigger verification, poll status until `ready`), plus end-to-end CI/CD automation that stitches Auth0 together with a DNS provider. DNS-provider-specific calls live in the per-provider sub-files — [providers/cloudflare.md](providers/cloudflare.md), [providers/route53.md](providers/route53.md), [providers/azure-dns.md](providers/azure-dns.md), or [providers/manual.md](providers/manual.md); the router at [providers.md](providers.md) picks one based on the root domain's NS records.

## cURL

### Create custom domain

```bash
curl --request POST \
  --url 'https://your-tenant.auth0.com/api/v2/custom-domains' \
  --header 'authorization: Bearer YOUR_MGMT_API_TOKEN' \
  --header 'content-type: application/json' \
  --data '{
    "domain": "login.example.com",
    "type": "auth0_managed_certs"
  }'
```

Response includes `custom_domain_id`, `status` (starts `pending_verification`), and `verification.methods[0].record` (the CNAME value to put in DNS).

### Trigger verification

```bash
curl --request POST \
  --url 'https://your-tenant.auth0.com/api/v2/custom-domains/cd_abc123/verify' \
  --header 'authorization: Bearer YOUR_MGMT_API_TOKEN'
```

### Poll status

```bash
curl --request GET \
  --url 'https://your-tenant.auth0.com/api/v2/custom-domains/cd_abc123' \
  --header 'authorization: Bearer YOUR_MGMT_API_TOKEN'
```

Stop polling when `status` is `ready`. Suggested backoff: 5, 10, 20, 30s, then 60s intervals up to ~10 minutes total.

### Set default domain (MCD only)

```bash
curl --request PATCH \
  --url 'https://your-tenant.auth0.com/api/v2/tenants/settings' \
  --header 'authorization: Bearer YOUR_MGMT_API_TOKEN' \
  --header 'content-type: application/json' \
  --data '{"default_custom_domain_id": "cd_abc123"}'
```

### Handling 403 on create (credit card required)

On Free-tier tenants without a credit card on file, `POST /custom-domains` returns 403. Inspect the status:

```bash
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --request POST \
  --url "https://${AUTH0_TENANT}/api/v2/custom-domains" \
  --header "authorization: Bearer ${AUTH0_TOKEN}" \
  --header "content-type: application/json" \
  --data '{"domain": "login.example.com", "type": "auth0_managed_certs"}')

if [ "$HTTP_STATUS" = "403" ]; then
  echo "Custom domains require a credit card on file for identity verification."
  echo "The card is not charged. Add one at Dashboard → Tenant Settings → Billing."
  exit 1
fi
```

Do not suggest a plan upgrade on 403; the fix is adding a card.

## CI/CD automation

End-to-end patterns that stitch Auth0 domain creation, DNS record provisioning, and verification polling. Useful for multi-environment setups and infrastructure-as-code pipelines.

### End-to-end script: Auth0 + Route 53

Creates the custom domain, writes the CNAME to Route 53, polls Route 53 until `INSYNC`, triggers Auth0 verification, and polls Auth0 until `ready`.

```bash
#!/bin/bash
set -euo pipefail

# Required env vars:
#   AUTH0_TENANT (e.g., acme-prod.us.auth0.com)
#   AUTH0_TOKEN (Management API token with create:custom_domains + read:custom_domains)
#   CUSTOM_DOMAIN (e.g., login.example.com)
#   ROUTE53_HOSTED_ZONE_ID (e.g., Z1234567890ABC)

# 1. Create custom domain in Auth0
CREATE_RESPONSE=$(curl -sf --request POST \
  --url "https://${AUTH0_TENANT}/api/v2/custom-domains" \
  --header "authorization: Bearer ${AUTH0_TOKEN}" \
  --header "content-type: application/json" \
  --data "{
    \"domain\": \"${CUSTOM_DOMAIN}\",
    \"type\": \"auth0_managed_certs\"
  }")

DOMAIN_ID=$(echo "$CREATE_RESPONSE" | jq -r '.custom_domain_id')
CNAME_VALUE=$(echo "$CREATE_RESPONSE" | jq -r '.verification.methods[0].record')

echo "Auth0 custom domain created: ${DOMAIN_ID}"
echo "CNAME ${CUSTOM_DOMAIN} -> ${CNAME_VALUE}"

# 2. Create CNAME in Route 53
CHANGE_RESPONSE=$(aws route53 change-resource-record-sets \
  --hosted-zone-id "${ROUTE53_HOSTED_ZONE_ID}" \
  --change-batch "{
    \"Changes\": [{
      \"Action\": \"UPSERT\",
      \"ResourceRecordSet\": {
        \"Name\": \"${CUSTOM_DOMAIN}\",
        \"Type\": \"CNAME\",
        \"TTL\": 300,
        \"ResourceRecords\": [{\"Value\": \"${CNAME_VALUE}\"}]
      }
    }]
  }" --output json)

CHANGE_ID=$(echo "$CHANGE_RESPONSE" | jq -r '.ChangeInfo.Id')
echo "Route 53 change submitted: ${CHANGE_ID}"

# 3. Wait for Route 53 to propagate
while true; do
  STATUS=$(aws route53 get-change --id "${CHANGE_ID}" --output json | jq -r '.ChangeInfo.Status')
  echo "Route 53 change status: ${STATUS}"
  [ "$STATUS" = "INSYNC" ] && break
  sleep 10
done

# 4. Trigger Auth0 verification
curl -sf --request POST \
  --url "https://${AUTH0_TENANT}/api/v2/custom-domains/${DOMAIN_ID}/verify" \
  --header "authorization: Bearer ${AUTH0_TOKEN}" > /dev/null

# 5. Poll Auth0 status with backoff
DELAYS=(5 10 20 30 60 60 60 60 60 60)
for delay in "${DELAYS[@]}"; do
  sleep "$delay"
  STATUS=$(curl -sf --request GET \
    --url "https://${AUTH0_TENANT}/api/v2/custom-domains/${DOMAIN_ID}" \
    --header "authorization: Bearer ${AUTH0_TOKEN}" | jq -r '.status')
  echo "Auth0 domain status: ${STATUS}"
  if [ "$STATUS" = "ready" ]; then
    echo "Custom domain ${CUSTOM_DOMAIN} is ready"
    exit 0
  fi
done

echo "Timed out waiting for custom domain to become ready"
exit 1
```

### Multi-environment pattern

Each environment gets its own custom domain. Script once, parametrize:

```text
environments/
  dev/
    AUTH0_TENANT=acme-dev.us.auth0.com
    CUSTOM_DOMAIN=login-dev.example.com
    ROUTE53_HOSTED_ZONE_ID=Z111
  staging/
    AUTH0_TENANT=acme-staging.us.auth0.com
    CUSTOM_DOMAIN=login-staging.example.com
    ROUTE53_HOSTED_ZONE_ID=Z222
  prod/
    AUTH0_TENANT=acme-prod.us.auth0.com
    CUSTOM_DOMAIN=login.example.com
    ROUTE53_HOSTED_ZONE_ID=Z333
```

Invoke the script once per environment, either sequentially in CI or via a matrix build.

### Idempotency

The script above is idempotent **for Route 53** (`UPSERT` creates or updates). For Auth0, creating a custom domain that already exists returns 409. To make the Auth0 step idempotent:

```bash
# Check if the domain already exists
EXISTING=$(curl -sf --request GET \
  --url "https://${AUTH0_TENANT}/api/v2/custom-domains" \
  --header "authorization: Bearer ${AUTH0_TOKEN}" | \
  jq -r ".[] | select(.domain == \"${CUSTOM_DOMAIN}\") | .custom_domain_id")

if [ -n "$EXISTING" ]; then
  DOMAIN_ID="$EXISTING"
  echo "Custom domain already exists: ${DOMAIN_ID}"
  # Fetch CNAME value from existing domain
  CNAME_VALUE=$(curl -sf --request GET \
    --url "https://${AUTH0_TENANT}/api/v2/custom-domains/${DOMAIN_ID}" \
    --header "authorization: Bearer ${AUTH0_TOKEN}" | \
    jq -r '.verification.methods[0].record')
else
  # ... create as above
fi
```

### Certificate renewal monitoring

Auth0-managed certs auto-renew every ~3 months. Renewal requires the CNAME to still be in DNS. For periodic monitoring, alert on:

- The domain's `status` field changing from `ready` to anything else (poll `GET /api/v2/custom-domains/{id}`)
- The CNAME disappearing from DNS (check with `dig +short CNAME {domain}`)

The **Check domain health** capability covers both for a one-off check.
