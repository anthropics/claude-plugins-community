## Step 3: Validate MFA on Backend

Always validate MFA status on the backend for sensitive operations.

### Node.js / Express

```typescript
import { expressjwt, GetVerificationKey } from 'express-jwt';
import { expressJwtSecret } from 'jwks-rsa';
import { Request, Response, NextFunction } from 'express';

// Extend Request type
interface AuthRequest extends Request {
  auth?: {
    sub: string;
    amr?: string[];
    acr?: string;
    [key: string]: any;
  };
}

// JWT validation middleware
const validateJwt = expressjwt({
  secret: expressJwtSecret({
    cache: true,
    rateLimit: true,
    jwksUri: `https://${process.env.AUTH0_DOMAIN}/.well-known/jwks.json`,
  }) as GetVerificationKey,
  audience: process.env.AUTH0_AUDIENCE,
  issuer: `https://${process.env.AUTH0_DOMAIN}/`,
  algorithms: ['RS256'],
});

// MFA requirement middleware
const requireMFA = (req: AuthRequest, res: Response, next: NextFunction) => {
  const amr = req.auth?.amr || [];

  if (!amr.includes('mfa')) {
    return res.status(403).json({
      error: 'MFA required',
      code: 'mfa_required',
      message: 'This action requires multi-factor authentication',
    });
  }

  next();
};

// Usage
app.post('/api/transfer', validateJwt, requireMFA, (req, res) => {
  // User has completed MFA
  res.json({ success: true });
});

// Optional: Check specific MFA methods
const requireTOTP = (req: AuthRequest, res: Response, next: NextFunction) => {
  const amr = req.auth?.amr || [];

  // Check for OTP-based MFA (TOTP)
  if (!amr.includes('otp') && !amr.includes('mfa')) {
    return res.status(403).json({
      error: 'TOTP required',
      code: 'totp_required',
    });
  }

  next();
};
```

### Python (Flask)

```python
from functools import wraps
from flask import request, jsonify, g
import jwt
from jwt import PyJWKClient

AUTH0_DOMAIN = os.environ.get('AUTH0_DOMAIN')
AUTH0_AUDIENCE = os.environ.get('AUTH0_AUDIENCE')

def require_auth(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        auth_header = request.headers.get('Authorization', '')
        if not auth_header.startswith('Bearer '):
            return jsonify({'error': 'Missing token'}), 401

        token = auth_header.split(' ')[1]

        try:
            jwks_url = f'https://{AUTH0_DOMAIN}/.well-known/jwks.json'
            jwks_client = PyJWKClient(jwks_url)
            signing_key = jwks_client.get_signing_key_from_jwt(token)

            payload = jwt.decode(
                token,
                signing_key.key,
                algorithms=['RS256'],
                audience=AUTH0_AUDIENCE,
                issuer=f'https://{AUTH0_DOMAIN}/'
            )
            g.user = payload
        except jwt.exceptions.PyJWTError as e:
            return jsonify({'error': f'Invalid token: {str(e)}'}), 401

        return f(*args, **kwargs)
    return decorated

def require_mfa(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        amr = g.user.get('amr', [])

        if 'mfa' not in amr:
            return jsonify({
                'error': 'MFA required',
                'code': 'mfa_required',
                'message': 'This action requires multi-factor authentication'
            }), 403

        return f(*args, **kwargs)
    return decorated

# Usage
@app.route('/api/transfer', methods=['POST'])
@require_auth
@require_mfa
def transfer():
    # User has completed MFA
    return jsonify({'success': True})
```

---
