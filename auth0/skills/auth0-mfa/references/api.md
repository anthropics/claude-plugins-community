## Common Patterns

### Pattern 1: Remember MFA for 30 Days

```typescript
// React: Check MFA age before requiring
const requireMFAIfStale = async (maxAgeSeconds = 30 * 24 * 60 * 60) => {
  const claims = await getIdTokenClaims();
  const authTime = claims?.auth_time;

  if (!authTime) return requireMFA();

  const authAge = Math.floor(Date.now() / 1000) - authTime;

  if (authAge > maxAgeSeconds) {
    return requireMFA({ maxAge: 0 });
  }

  return hasMFA();
};
```

### Pattern 2: MFA Challenge for High-Value Transactions

```typescript
// Frontend
const transferFunds = async (amount: number) => {
  // Require MFA for transfers over $1000
  if (amount > 1000) {
    const verified = await requireMFA();
    if (!verified) return;
  }

  await api.post('/transfer', { amount });
};

// Backend middleware
const requireMFAForHighValue = (threshold: number) => {
  return (req, res, next) => {
    const amount = req.body?.amount || 0;

    if (amount > threshold) {
      const amr = req.auth?.amr || [];
      if (!amr.includes('mfa')) {
        return res.status(403).json({
          error: 'MFA required for high-value transactions',
          code: 'mfa_required',
        });
      }
    }

    next();
  };
};

app.post('/transfer', validateJwt, requireMFAForHighValue(1000), handleTransfer);
```

### Pattern 3: MFA Status Display

```typescript
// React component showing MFA status
function MFAStatus() {
  const { getIdTokenClaims } = useAuth0();
  const [mfaStatus, setMfaStatus] = useState<string[]>([]);

  useEffect(() => {
    getIdTokenClaims().then(claims => {
      setMfaStatus(claims?.amr || []);
    });
  }, []);

  const getMFALabel = (method: string) => {
    const labels: Record<string, string> = {
      'mfa': 'Multi-Factor Auth',
      'otp': 'Authenticator App',
      'sms': 'SMS Code',
      'email': 'Email Code',
      'pwd': 'Password',
      'hwk': 'Security Key',
    };
    return labels[method] || method;
  };

  return (
    <div>
      <h3>Authentication Methods Used:</h3>
      <ul>
        {mfaStatus.map(method => (
          <li key={method}>{getMFALabel(method)}</li>
        ))}
      </ul>
    </div>
  );
}
```

---

## Error Handling

| Error | Cause | Solution |
|-------|-------|----------|
| `mfa_required` | User hasn't completed MFA | Redirect with `acr_values` parameter |
| `mfa_registration_required` | User has no MFA enrolled | Direct to enrollment or enable self-enrollment |
| `mfa_invalid_code` | Wrong OTP code entered | Prompt user to retry |
| `too_many_attempts` | Too many failed MFA attempts | Wait or contact support |
| `unsupported_challenge_type` | MFA factor not enabled | Enable the factor in dashboard |

---

## AMR Claim Values

The `amr` (Authentication Methods Reference) claim indicates how the user authenticated:

| Value | Meaning |
|-------|---------|
| `pwd` | Password authentication |
| `mfa` | Multi-factor authentication completed |
| `otp` | One-time password (TOTP) |
| `sms` | SMS verification |
| `email` | Email verification |
| `hwk` | Hardware key (WebAuthn) |
| `swk` | Software key |
| `pop` | Proof of possession |
| `fed` | Federated authentication (social/enterprise) |

---

## Testing

### Verify MFA is Working

1. **Enable MFA** in Auth0 Dashboard
2. **Login** and complete MFA enrollment
3. **Check ID token** for `amr` claim containing `mfa`
4. **Test step-up** by calling endpoint requiring MFA
5. **Verify backend** rejects requests without MFA

### Test Commands

```bash
# Check if MFA is enabled
auth0 api get "guardian/factors"

# List user's enrollments
auth0 api get "users/USER_ID/authenticators"

# Check MFA policy
auth0 api get "guardian/policies"
```

---

## Security Considerations

- **Always validate MFA on the backend** - Never trust frontend-only checks
- **Use `max_age=0`** for sensitive operations to force fresh authentication
- **Prefer TOTP/WebAuthn** over SMS (SIM swapping risk)
- **Enable recovery codes** so users don't get locked out
- **Log MFA events** for security auditing
- **Consider adaptive MFA** to balance security and UX

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
