# Auth0 Next.js Integration Patterns

Server-side and client-side auth patterns for both App and Pages Router.

---

## Protected Pages

### App Router - Server Component

```typescript
// app/profile/page.tsx
import { auth0 } from '@/lib/auth0';
import { redirect } from 'next/navigation';

export default async function Profile() {
  // In App Router, getSession() reads the request/response from Next.js' async context,
  // so you don't pass req/res like in the Pages Router example below.
  const session = await auth0.getSession();

  if (!session) {
    redirect('/auth/login?returnTo=/profile');
  }

  return (
    <div>
      <h1>Welcome, {session.user.name}!</h1>
      <img src={session.user.picture} alt={session.user.name} />
    </div>
  );
}
```

### Pages Router - SSR

```typescript
// pages/profile.tsx
import { auth0 } from '@/lib/auth0';
import { GetServerSideProps } from 'next';

export default function Profile({ user }: { user: any }) {
  return <h1>Welcome, {user.name}!</h1>;
}

export const getServerSideProps: GetServerSideProps = async ({ req, res }) => {
  const session = await auth0.getSession(req, res);

  if (!session) {
    return {
      redirect: {
        destination: '/auth/login?returnTo=/profile',
        permanent: false,
      },
    };
  }

  return {
    props: { user: session.user },
  };
};
```

---

## Protected API Routes

### App Router

```typescript
// app/api/private/route.ts
import { auth0 } from '@/lib/auth0';
import { NextResponse } from 'next/server';

export async function GET(request: Request) {
  const session = await auth0.getSession();

  if (!session) {
    return new NextResponse('Unauthorized', { status: 401 });
  }

  return NextResponse.json({ data: 'Protected data', user: session.user });
}
```

### Pages Router

```typescript
// pages/api/private.ts
import { auth0 } from '@/lib/auth0';
import { NextApiRequest, NextApiResponse } from 'next';

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  const session = await auth0.getSession(req, res);

  if (!session) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  res.json({ user: session.user });
}
```

---

## Middleware (App Router)

Protect multiple routes with middleware.

**File placement:** If the project uses a `src/` directory (i.e. `src/app/` exists), place `middleware.ts` or `proxy.ts` inside `src/`. Otherwise, place at the project root.

**Next.js 15** - Use `middleware.ts` (or `src/middleware.ts`):

```typescript
// middleware.ts
import { NextRequest, NextResponse } from 'next/server';
import { auth0 } from '@/lib/auth0';

export async function middleware(request: NextRequest) {
  const authRes = await auth0.middleware(request);

  // Allow auth routes to be handled by SDK
  if (request.nextUrl.pathname.startsWith('/auth')) {
    return authRes;
  }

  // Public routes
  if (request.nextUrl.pathname === '/') {
    return authRes;
  }

  // Protected routes - check session
  const session = await auth0.getSession(request);

  if (!session) {
    const { origin } = new URL(request.url);
    return NextResponse.redirect(`${origin}/auth/login?returnTo=${request.nextUrl.pathname}`);
  }

  return authRes;
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|sitemap.xml|robots.txt).*)',
  ],
};
```

**Next.js 16** - Use either `middleware.ts` (same as above) or `proxy.ts` (same `src/` placement rules):

```typescript
// proxy.ts
import { NextRequest, NextResponse } from 'next/server';
import { auth0 } from '@/lib/auth0';

export async function proxy(request: NextRequest) {
  const authRes = await auth0.middleware(request);

  // Allow auth routes to be handled by SDK
  if (request.nextUrl.pathname.startsWith('/auth')) {
    return authRes;
  }

  // Public routes
  if (request.nextUrl.pathname === '/') {
    return authRes;
  }

  // Protected routes - check session
  const session = await auth0.getSession(request);

  if (!session) {
    const { origin } = new URL(request.url);
    return NextResponse.redirect(`${origin}/auth/login?returnTo=${request.nextUrl.pathname}`);
  }

  return authRes;
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|sitemap.xml|robots.txt).*)',
  ],
};
```

---

## Calling External APIs

### App Router - Server Action

```typescript
// app/actions.ts
'use server';

import { auth0 } from '@/lib/auth0';

export async function getData() {
  const { token } = await auth0.getAccessToken();

  if (!token) {
    throw new Error('No access token available');
  }

  const response = await fetch('https://your-api.com/data', {
    headers: { Authorization: `Bearer ${token}` }
  });

  return response.json();
}
```

### Pages Router - API Route

```typescript
// pages/api/data.ts
import { auth0 } from '@/lib/auth0';
import { NextApiRequest, NextApiResponse } from 'next';

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  const session = await auth0.getSession(req, res);

  if (!session) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  const { token } = await auth0.getAccessToken(req, res);

  if (!token) {
    return res.status(401).json({ error: 'No access token' });
  }

  const response = await fetch('https://your-api.com/data', {
    headers: { Authorization: `Bearer ${token}` }
  });

  const data = await response.json();
  res.json(data);
}
```

---

## Common Issues

| Issue | Solution |
|-------|----------|
| "Invalid state" error | Regenerate `AUTH0_SECRET`, clear cookies |
| Client secret required | Next.js uses Regular Web Application type |
| Callback URL mismatch | Add `/auth/callback` to Allowed Callback URLs (v4 dropped `/api` prefix) |
| Middleware not protecting routes | Ensure middleware calls `auth0.middleware()` and check `matcher` config |
| Routes return 404 | v4 uses `/auth/*` paths, not `/api/auth/*` - update all auth links |

---

## Next Steps

- [API Reference](api.md) - Complete SDK documentation
- [Setup Guide](setup.md) - Installation guide
- [Main Skill](../SKILL.md) - Quick start
