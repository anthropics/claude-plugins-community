---
name: auth0-mfa
description: >
  Use when adding MFA or step-up authentication to an app — requiring users to verify with a second factor (TOTP, SMS, passkey, push) for login or before a sensitive action. Also use for adaptive/risk-based MFA or compliance requirements like HIPAA or PCI-DSS, even if the user just says "add two-factor auth" or "require MFA before this action".
license: Apache-2.0
metadata:
  author: Auth0 <support@auth0.com>
  version: '1.0.0'
  openclaw:
    emoji: "\U0001F510"
    homepage: https://github.com/auth0/agent-skills
    requires:
      bins:
        - auth0
    os:
      - darwin
      - linux
    install:
      - id: brew
        kind: brew
        package: auth0/auth0-cli/auth0
        bins: [auth0]
        label: 'Install Auth0 CLI (brew)'
---

# Auth0 MFA Guide

Add Multi-Factor Authentication to protect user accounts and require additional verification for sensitive operations.

---

## Overview

### What is MFA?

Multi-Factor Authentication (MFA) requires users to provide two or more verification factors to access their accounts. Auth0 supports multiple MFA factors and enables step-up authentication for sensitive operations.

### When to Use This Skill

- Adding MFA to protect user accounts
- Requiring additional verification for sensitive actions (payments, settings changes)
- Implementing adaptive/risk-based authentication
- Meeting compliance requirements (PCI-DSS, SOC2, HIPAA)

### MFA Factors Supported

| Factor | Type | Description |
|--------|------|-------------|
| TOTP | Something you have | Time-based one-time passwords (Google Authenticator, Authy) |
| SMS | Something you have | One-time codes via text message |
| Email | Something you have | One-time codes via email |
| Push | Something you have | Push notifications via Auth0 Guardian app |
| WebAuthn | Something you have/are | Security keys, biometrics, passkeys |
| Voice | Something you have | One-time codes via phone call |
| Recovery Code | Backup | One-time use recovery codes |

### Key Concepts

| Concept | Description |
|---------|-------------|
| `acr_values` | Request MFA during authentication |
| `amr` claim | Authentication Methods Reference - indicates how user authenticated |
| Step-up auth | Require MFA for specific actions after initial login |
| Adaptive MFA | Conditionally require MFA based on risk signals |

---

## Step 1: Enable MFA in Tenant

### Via Auth0 Dashboard

1. Go to **Security → Multi-factor Auth**
2. Enable desired factors (TOTP, SMS, etc.)
3. Configure **Policies**:
   - **Always** - Require MFA for all logins
   - **Adaptive** - Risk-based MFA
   - **Never** - Disable MFA (use step-up instead)

### Via Auth0 CLI

```bash
# View current MFA configuration
auth0 api get "guardian/factors"

# Enable TOTP (One-time Password)
auth0 api put "guardian/factors/otp" --data '{"enabled": true}'

# Enable SMS
auth0 api put "guardian/factors/sms" --data '{"enabled": true}'

# Enable Push notifications
auth0 api put "guardian/factors/push-notification" --data '{"enabled": true}'

# Enable WebAuthn (Roaming - Security Keys)
auth0 api put "guardian/factors/webauthn-roaming" --data '{"enabled": true}'

# Enable WebAuthn (Platform - Biometrics)
auth0 api put "guardian/factors/webauthn-platform" --data '{"enabled": true}'

# Enable Email
auth0 api put "guardian/factors/email" --data '{"enabled": true}'
```

### Configure MFA Policy

```bash
# Set MFA policy: "all-applications" or "confidence-score"
auth0 api patch "guardian/policies" --data '["all-applications"]'
```

---

## Step 2: Implement Step-Up Authentication

Step-up auth requires MFA for sensitive operations without requiring it for every login.

### The `acr_values` Parameter

Request MFA by including `acr_values` in your authorization request:

```
acr_values=http://schemas.openid.net/pape/policies/2007/06/multi-factor
```

### Implementation Pattern

The general pattern for all frameworks:

1. Check if user has already completed MFA (inspect `amr` claim)
2. If not, request MFA via `acr_values` parameter
3. Proceed with sensitive action once MFA is verified

**For complete framework-specific examples, see [Examples Guide](references/examples.md):**
- React (basic and custom hook)
- Next.js (App Router)
- Vue.js
- Angular

---

## Additional Resources

This skill is split into multiple files for better organization:

### [Step-Up Examples](references/examples.md)
Complete code examples for all frameworks:
- React (basic and custom hook patterns)
- Next.js (App Router with API routes)
- Vue.js (composition API)
- Angular (services and components)

### [Backend Validation](references/backend.md)
Learn how to validate MFA status on your backend:
- Node.js / Express JWT validation
- Python / Flask validation
- Middleware examples

### [Advanced Topics](references/advanced.md)
Advanced MFA implementation patterns:
- Adaptive MFA with Auth0 Actions
- Conditional MFA based on risk signals
- MFA Enrollment API

### [Reference Guide](references/api.md)
Common patterns and troubleshooting:
- Remember MFA for 30 days
- MFA for high-value transactions
- MFA status display
- Error handling
- AMR claim values
- Testing strategies
- Security considerations

---

## Related Skills

- `auth0-quickstart` - Basic Auth0 setup
- `auth0-passkeys` - WebAuthn/passkey implementation
- `auth0-actions` - Custom authentication logic

---

## References

- [Auth0 MFA Documentation](https://auth0.com/docs/secure/multi-factor-authentication)
- [Step-Up Authentication](https://auth0.com/docs/secure/multi-factor-authentication/step-up-authentication)
- [MFA API](https://auth0.com/docs/secure/multi-factor-authentication/manage-mfa-auth0-apis)
- [acr_values Parameter](https://auth0.com/docs/get-started/authentication-and-authorization-flow/authorization-code-flow/add-login-auth-code-flow#request-parameters)
