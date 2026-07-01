---
description: Find unsanctioned and unreviewed (shadow IT) applications in the environment
---

# Check Shadow IT

Identify unsanctioned and unreviewed SaaS applications in the environment.

## Steps

1. **Unsanctioned apps**: Call `list_apps` with filter `status eq "UNSANCTIONED" and limit eq 50`. These are apps explicitly flagged as not allowed.

2. **Unreviewed apps**: Call `list_apps` with filter `status eq "UNREVIEWED" and limit eq 50`. These are apps that have been discovered but not yet assessed.

3. **OAuth exposure from shadow apps**: Call `list_saas_to_saas` with filter `limit eq 50`. Look for grants where the source app is UNSANCTIONED or UNREVIEWED — these represent shadow apps with access to sanctioned data.

4. **Exposure per top shadow app**: For the top 3–5 unsanctioned/unreviewed apps by user count, call `list_accounts` with filter `application eq "AppName" and limit eq 20` to understand who is using them.

## Output

- **Shadow IT summary**: count of unsanctioned vs unreviewed apps, total users exposed
- **Highest risk unreviewed apps**: ranked by user count and risk score, with app category and risk factors
- **OAuth exposure**: unsanctioned/unreviewed apps that hold OAuth grants into sanctioned apps (these are the highest risk)
- **Recommended actions**: which apps to review immediately, which to block, and any OAuth grants to revoke
