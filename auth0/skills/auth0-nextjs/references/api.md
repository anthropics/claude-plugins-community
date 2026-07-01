## Common Patterns

### Custom Login with Options

```typescript
<a href="/auth/login?returnTo=/dashboard">
  Login and go to Dashboard
</a>
```

Or programmatically:

```typescript
const router = useRouter();
router.push('/auth/login?returnTo=/dashboard');
```

---

### Get Access Token for External APIs

```typescript
import { auth0 } from '@/lib/auth0';
import { NextResponse } from 'next/server';

export async function GET() {
  const { token } = await auth0.getAccessToken();

  if (!token) {
    return new NextResponse('Unauthorized', { status: 401 });
  }

  const apiResponse = await fetch('https://external-api.com/data', {
    headers: {
      Authorization: `Bearer ${token}`
    }
  });

  return NextResponse.json(await apiResponse.json());
}
```

---

### Silent Authentication

Users remain logged in across sessions automatically with refresh tokens.

To force re-authentication:

```typescript
<a href="/auth/login?prompt=login">
  Force Re-login
</a>
```

---

## Configuration Options

### Advanced Auth0 Configuration

Create `lib/auth0.ts`:

```typescript
import { Auth0Client } from '@auth0/nextjs-auth0/server';

export const auth0 = new Auth0Client({
  domain: process.env.AUTH0_DOMAIN!,
  clientId: process.env.AUTH0_CLIENT_ID!,
  clientSecret: process.env.AUTH0_CLIENT_SECRET!,
  secret: process.env.AUTH0_SECRET!,
  appBaseUrl: process.env.APP_BASE_URL!,
  authorizationParameters: {
    scope: 'openid profile email',
    audience: process.env.AUTH0_AUDIENCE,
  },
  routes: {
    login: '/auth/login',
    callback: '/auth/callback',
    logout: '/auth/logout',
    profile: '/auth/profile',
  },
  session: {
    rolling: true,
    rollingDuration: 24 * 60 * 60, // 24 hours in seconds
    absoluteDuration: 7 * 24 * 60 * 60, // 7 days in seconds
  },
});
```

**Note:** Most configuration can be omitted - v4 uses sensible defaults. The middleware automatically mounts auth routes.

---

## Testing

1. Start your dev server: `npm run dev`
2. Visit `http://localhost:3000`
3. Click "Login" - redirects to Auth0
4. Complete authentication
5. Verify redirect back with user session
6. Test protected pages and API routes
7. Click "Logout" and verify session cleared

---

## Common Issues

| Issue | Solution |
|-------|----------|
| "Missing required parameter: redirect_uri" | Ensure `APP_BASE_URL` is set correctly (v4 renamed from `AUTH0_BASE_URL`) |
| "Invalid state" error | Clear cookies/storage. Verify callback URL in Auth0 dashboard matches `APP_BASE_URL/auth/callback` |
| User session not persisting | Check `AUTH0_SECRET` is set and at least 32 characters |
| API routes return 401 | Check session with `auth0.getSession()` in route handler |
| Middleware loops infinitely | Ensure middleware matcher excludes `/auth/*` routes, not `/api/auth/*` |
| Import errors for v3 helpers | v4 removed `withApiAuthRequired` and `withPageAuthRequired` - use `auth0.getSession()` |
| Environment variable not recognized | v4 uses `AUTH0_DOMAIN` (no scheme) and `APP_BASE_URL`, not `AUTH0_ISSUER_BASE_URL` or `AUTH0_BASE_URL` |

---

## Security Considerations

- **Keep secrets secure** - Never commit `.env.local` to version control
- **Use HTTPS in production** - Auth0 requires secure callback URLs
- **Rotate secrets regularly** - Update `AUTH0_SECRET` periodically
- **Validate on server** - Always verify authentication server-side, not client-side
- **Configure CORS** - Set allowed origins in Auth0 application settings

---

## Related Skills

- `auth0-quickstart` - Initial Auth0 account setup
- `auth0-migration` - Migrate from another auth provider
- `auth0-mfa` - Add Multi-Factor Authentication
- `auth0-organizations` - B2B multi-tenancy support
- `auth0-passkeys` - Add passkey authentication

---

## References

- [Auth0 Next.js SDK Documentation](https://auth0.com/docs/libraries/nextjs-auth0)
- [Auth0 Next.js SDK GitHub](https://github.com/auth0/nextjs-auth0)
- [Auth0 Next.js Quickstart](https://auth0.com/docs/quickstart/webapp/nextjs)
- [Next.js Middleware Documentation](https://nextjs.org/docs/app/building-your-application/routing/middleware)
