# Azure DNS (Tier 3: Assisted Automation)

Uses the Azure CLI. If the user is signed in, this tier handles the CNAME creation automatically. Otherwise it falls back to [manual guided](manual.md).

## Plan requirements

Azure DNS has **no plan tiers**. Any active Azure subscription (pay-as-you-go, EA, CSP, Visual Studio credit, free trial) can host public DNS zones. Pricing is $0.50/zone/month for the first 25 zones (lower after) plus $0.40 per million queries.

What the signed-in identity needs:
- The **DNS Zone Contributor** role on the resource group containing the zone, or
- The broader **Contributor** / **Owner** role on the resource group or subscription.

The `Reader` role alone is insufficient; record-set writes return 403. Default subscription limit is **250 public DNS zones per subscription**, raisable via support.

## Pre-flight check

```bash
az account show
```

If this returns an active subscription, proceed. Otherwise drop to [manual guided](manual.md) with the Azure portal deep-link.

## Find the DNS zone

```bash
az network dns zone list \
  --query "[?name=='example.com'].{name:name, rg:resourceGroup}" \
  -o json
```

Extract the resource group. If the zone is in a subscription different from the current default, the user may need to run `az account set --subscription <id>` first.

## Create the CNAME record

Azure CLI's record-set create and set-record are separate commands. Use `set-record` which handles both cases:

```bash
az network dns record-set cname set-record \
  --resource-group my-rg \
  --zone-name example.com \
  --record-set-name login \
  --cname tenant.edge.tenants.auth0.com \
  --ttl 300
```

Notes:
- `--record-set-name` is the relative name (`login`), not the full FQDN.
- Azure DNS CNAME record sets can only contain a single record. If one already exists with a different value, you must delete the existing record-set first (confirm with user):

```bash
az network dns record-set cname delete \
  --resource-group my-rg \
  --zone-name example.com \
  --name login \
  --yes
```

## Propagation

Azure DNS propagates quickly (typically <30s). No polling equivalent to Route 53's `INSYNC` check is needed. Proceed directly to Auth0 verification.

## Fallback deep-link

```text
https://portal.azure.com/#view/HubsExtension/BrowseResource/resourceType/Microsoft.Network%2FdnsZones
```
Instruct the user to select their zone, then **+ Record set**.
