---
description: Deep-dive security investigation for a specific SaaS application
argument-hint: Application name (e.g. "Slack", "GitHub", "Salesforce")
---

# Investigate App: $ARGUMENTS

Perform a comprehensive security investigation of the application "$ARGUMENTS".

## Steps

1. **App overview**: Call `list_apps` with filter `name eq "$ARGUMENTS"` to get the risk score, category, and risk factors. If no exact match, try `name co "$ARGUMENTS"`.

2. **Open posture issues**: Call `list_posture_issues` with filter `application eq "$ARGUMENTS" and (checkStatus eq "ALERT_STATUS_NEW" or checkStatus eq "ALERT_STATUS_TO_REVIEW")` to find failing security checks.

3. **Active alerts**: Call `list_threat_alerts` with filter `application eq "$ARGUMENTS"` for any active threat detections.

4. **User access**: Call `list_accounts` with filter `application eq "$ARGUMENTS" and limit eq 20` to see who has access. Note total count.

5. **App-to-app OAuth grants**: Call `list_saas_to_saas` with filter `targetApplication eq "$ARGUMENTS"` to see which other apps have OAuth access into this one.

6. **Recent activity**: Call `list_events` with filter `application eq "$ARGUMENTS" and limit eq 20` for recent events. Flag any with `outcome_string eq "failure"`.

## Output

Produce a structured security brief:

- **Risk summary**: overall risk score, top risk factors, whether the app is sanctioned
- **Open posture issues**: count by severity (CRITICAL/HIGH/MEDIUM/LOW), most critical items with remediation steps
- **Active alerts**: any threat detections and their severity
- **Access exposure**: total user count, any accounts flagged as overprivileged or admin
- **App-to-app exposure**: which apps hold OAuth grants into this one
- **Recent activity**: anything anomalous (failures, off-hours, unexpected event types)
- **Recommended actions**: 3–5 prioritized steps, starting with CRITICAL severity items
