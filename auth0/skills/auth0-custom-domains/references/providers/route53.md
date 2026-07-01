# AWS Route 53 (Tier 2: Assisted Automation)

Uses the AWS CLI. If the user already has AWS credentials configured (env vars, shared config, or SSO session), this tier handles the CNAME creation automatically. Otherwise it falls back to [manual guided](manual.md).

## Plan requirements

Route 53 has **no plan tiers**. It's pay-per-use:
- ~$0.50/hosted zone/month for the first 25 zones (lower per-zone after).
- $0.40 per million queries for the first billion (lower after).
- Route 53 is **not included in the AWS free tier**, even on new accounts.
- Default API rate limit is 5 requests/second per account; the skill's verify-poll backoff stays well under this.

What the calling identity needs:
- `route53:ListHostedZonesByName` (read)
- `route53:ListResourceRecordSets` (read)
- `route53:ChangeResourceRecordSets` (write, for create and delete)
- `route53:GetChange` (read, for INSYNC polling)

The `AmazonRoute53FullAccess` managed policy covers all of these; a least-privilege custom policy scoped to the hosted zone ARN is cleaner for production.

## Pre-flight check

```bash
aws sts get-caller-identity
```

If this returns identity info, proceed. If it errors with credentials/expired token, drop to [manual guided](manual.md) with a Route 53 console deep-link.

## Find the hosted zone

```bash
aws route53 list-hosted-zones-by-name \
  --dns-name example.com \
  --max-items 1
```

Extract the hosted zone ID (strip the `/hostedzone/` prefix). Watch for private vs public zones; Auth0 needs a public zone. If the result is a private hosted zone, fall back to manual with an explanation.

## Create the CNAME record

```bash
aws route53 change-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "login.example.com",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [{"Value": "tenant.edge.tenants.auth0.com"}]
      }
    }]
  }'
```

`UPSERT` creates the record if it doesn't exist and updates it if it does. Before calling, list existing records at the target name and confirm overwrite with the user if one is present with a different value:

```bash
aws route53 list-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --start-record-name login.example.com \
  --start-record-type CNAME \
  --max-items 1
```

## Poll until `INSYNC`

The `change-resource-record-sets` response contains a `ChangeInfo.Id`. Poll it:

```bash
aws route53 get-change --id /change/C1234567890ABC
```

The `Status` field returns `PENDING` then `INSYNC`. Wait for `INSYNC` (usually ~60s) before triggering Auth0 verification.

## Delete the CNAME record (the Remove a custom domain flow)

DELETE on Route 53 is stricter than UPSERT: the submitted record must **exactly match** the live record on `Name`, `Type`, `TTL`, and every `Value` in `ResourceRecords`. A mismatched TTL silently fails with `InvalidChangeBatch: Tried to delete resource record set ... but it was not found`. Always fetch the current record first and copy its exact values into the DELETE batch.

```bash
# 1. Read the current record's exact values
aws route53 list-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --start-record-name login.example.com \
  --start-record-type CNAME \
  --max-items 1
```

```bash
# 2. Submit the DELETE with exact-match values (substitute TTL and Value from step 1)
aws route53 change-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --change-batch '{
    "Changes": [{
      "Action": "DELETE",
      "ResourceRecordSet": {
        "Name": "login.example.com",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [{"Value": "tenant.edge.tenants.auth0.com"}]
      }
    }]
  }'
```

Poll `get-change` until `INSYNC` to confirm propagation before reporting success.

## Error handling

- `PriorRequestNotComplete`: another change on the same zone is still propagating. Back off and retry (5s, 10s, 20s).
- `InvalidChangeBatch` on DELETE: the submitted record doesn't exactly match the live record. Re-run the list step above and copy the TTL and Value precisely.
- Rate limit: Route 53 allows 5 req/s per account. With the skill's backoff on verify polling, this is not usually a concern.

## Fallback deep-link

If pre-flight fails:
```text
https://console.aws.amazon.com/route53/v2/hostedzones
```
Instruct the user to click their zone, then "Create record".
