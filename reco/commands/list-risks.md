---
description: Surface current HIGH and CRITICAL security risks across the environment
argument-hint: "Optional minimum severity - LOW, MEDIUM, HIGH, or CRITICAL (default: HIGH)"
---

# List Risks

Surface current high-priority security risks in the environment.

Minimum severity: $ARGUMENTS (use HIGH if not specified).

## Steps

1. **Posture issues**: Call `list_posture_issues` with filter `(severity eq "CRITICAL" or severity eq "HIGH") and (checkStatus eq "ALERT_STATUS_NEW" or checkStatus eq "ALERT_STATUS_TO_REVIEW") and limit eq 50`. Adjust severity based on the argument if provided.

2. **Threat alerts**: Call `list_threat_alerts` with filter `severity eq "CRITICAL" or severity eq "HIGH"` for active anomaly alerts. Adjust severity if needed.

3. **Group and rank**:
   - By security domain (IAM, Data Protection, Application Security, etc.)
   - By severity within each domain
   - By number of affected entities (highest impact first)

## Output

Produce a prioritized risk dashboard:

- **Critical items** (CRITICAL severity): list each with name, affected entity count, and remediation instructions
- **High items** (HIGH severity): grouped by security domain, top 5 per domain
- **Top 3 recommended actions**: the highest-leverage remediations with specific steps
- **Summary stats**: total open issues by severity, total affected entities
