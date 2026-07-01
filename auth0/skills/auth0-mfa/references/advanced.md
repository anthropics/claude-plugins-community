## Step 4: Adaptive MFA with Actions

Use Auth0 Actions to require MFA based on conditions.

### Create Action: Conditional MFA

```javascript
// Action: Require MFA for Sensitive Operations
// Trigger: Login / Post Login

exports.onExecutePostLogin = async (event, api) => {
  // Always require MFA for admins
  const roles = event.authorization?.roles || [];
  if (roles.includes('admin')) {
    if (event.authentication?.methods?.find(m => m.name === 'mfa')) {
      return; // MFA already completed
    }
    api.multifactor.enable('any', { allowRememberBrowser: false });
    return;
  }

  // Require MFA for new devices
  const isNewDevice = !event.authentication?.methods?.find(
    m => m.name === 'pwd' && m.timestamp
  );

  if (isNewDevice) {
    api.multifactor.enable('any', { allowRememberBrowser: true });
    return;
  }

  // Require MFA for suspicious locations
  const riskAssessment = event.request?.geoip;
  const userCountry = event.user?.user_metadata?.country;

  if (riskAssessment?.countryCode !== userCountry) {
    api.multifactor.enable('any', { allowRememberBrowser: false });
    return;
  }
};
```

### Create Action: MFA Based on Requested Scopes

```javascript
// Action: MFA for Sensitive Scopes
// Trigger: Login / Post Login

exports.onExecutePostLogin = async (event, api) => {
  const requestedScopes = event.request?.query?.scope?.split(' ') || [];
  const sensitiveScopes = ['transfer:funds', 'admin:write', 'delete:users'];

  const requiresMFA = requestedScopes.some(scope =>
    sensitiveScopes.includes(scope)
  );

  if (requiresMFA) {
    const hasMFA = event.authentication?.methods?.find(m => m.name === 'mfa');
    if (!hasMFA) {
      api.multifactor.enable('any');
    }
  }
};
```

### Deploy Action via CLI

```bash
# Create the action
auth0 actions create \
  --name "Conditional MFA" \
  --trigger post-login \
  --code "$(cat conditional-mfa.js)"

# Deploy the action
auth0 actions deploy ACTION_ID

# Attach to login flow
auth0 api patch "actions/triggers/post-login/bindings" --data '{
  "bindings": [{"ref": {"type": "action_id", "value": "ACTION_ID"}}]
}'
```

---

## Step 5: MFA Enrollment API

For custom enrollment experiences, use the MFA API.

### List User's MFA Enrollments

```bash
# Get user's enrolled authenticators
curl -X GET "https://YOUR_DOMAIN/api/v2/users/USER_ID/authenticators" \
  -H "Authorization: Bearer MGMT_TOKEN"
```

### Delete an Enrollment

```bash
# Remove an authenticator
curl -X DELETE "https://YOUR_DOMAIN/api/v2/users/USER_ID/authenticators/AUTHENTICATOR_ID" \
  -H "Authorization: Bearer MGMT_TOKEN"
```

### Trigger Enrollment Email

```bash
# Send enrollment email to user
curl -X POST "https://YOUR_DOMAIN/api/v2/guardian/enrollments/ticket" \
  -H "Authorization: Bearer MGMT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "USER_ID",
    "send_mail": true
  }'
```

---
