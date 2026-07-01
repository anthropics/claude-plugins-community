---
name: auth0-migration
description: >
  Use when migrating users or authentication from another provider (Firebase, Cognito, Supabase, Clerk, or custom auth) to Auth0. Covers bulk user import, gradual migration strategies, and updating JWT validation — use even if the user says "switch our auth to Auth0" or "move our users to Auth0".
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

# Auth0 Migration Guide

Migrate users and authentication flows from existing auth providers to Auth0.

---

## Overview

### When to Use This Skill

- Migrating from another auth provider to Auth0
- Bulk importing existing users
- Gradually transitioning active user bases
- Updating JWT validation in APIs

## When NOT to Use

- **Starting fresh with Auth0** - Use `auth0-quickstart` for new projects without existing users
- **Already using Auth0** - This is for migrating TO Auth0, not between Auth0 tenants
- **Only adding MFA or features** - Use feature-specific skills if just adding capabilities

### Migration Approaches

- **Bulk Migration:** One-time user import (recommended for small/inactive bases)
- **Gradual Migration:** Lazy migration over time (recommended for large active bases)
- **Hybrid:** Import inactive users, lazy-migrate active users

---

## Step 0: Detect Existing Auth Provider

**Check if the project already has authentication:**

Search for common auth-related patterns in the codebase:

| Pattern | Indicates |
|---------|-----------|
| `signInWithEmailAndPassword`, `onAuthStateChanged` | Firebase Auth |
| `useUser`, `useSession`, `isSignedIn` | Existing auth hooks |
| `passport.authenticate`, `LocalStrategy` | Passport.js |
| `authorize`, `getAccessToken`, `oauth` | OAuth/OIDC |
| `JWT`, `jwt.verify`, `jsonwebtoken` | Token-based auth |
| `/api/auth/`, `/login`, `/callback` | Auth routes |

**If existing auth detected, ask:**

> I detected existing authentication in your project. Are you:
> 1. **Migrating to Auth0** (replace existing auth)
> 2. **Adding Auth0 alongside** (keep both temporarily)
> 3. **Starting fresh** (remove old auth, new Auth0 setup)

---

## Migration Workflow

### Step 1: Export Existing Users

Export users from your current provider. See [User Import Guide](references/user-import.md) for detailed instructions:
- [Exporting from Firebase](references/user-import.md#firebase)
- [Exporting from AWS Cognito](references/user-import.md#aws-cognito)
- [Exporting from Supabase](references/user-import.md#supabase)
- [Exporting from Custom Database](references/user-import.md#custom-database)

**Required data per user:**
- Email address
- Email verified status
- Password hash (if available)
- User metadata/profile data
- Creation timestamp

---

### Step 2: Import Users to Auth0

Import users via Dashboard, CLI, or Management API.

**Quick start:**
```bash
# Via Auth0 CLI
auth0 api post "jobs/users-imports" \
  --data "connection_id=con_ABC123" \
  --data "users=@users.json"
```

**For detailed instructions:**
- [User JSON Format](references/user-import.md#auth0-user-import-format)
- [Password Hash Algorithms](references/user-import.md#password-hash-algorithms)
- [Import Methods](references/user-import.md#importing-to-auth0)
- [Monitoring Import Progress](references/user-import.md#monitoring-import-progress)
- [Common Import Errors](references/user-import.md#common-import-errors)

---

### Step 3: Migrate Application Code

Update your application code to use Auth0 SDKs.

**See [Code Migration Patterns](references/code-patterns.md) for detailed before/after examples:**

**Frontend:**
- [React Migration](references/code-patterns.md#react-migration)
- [Next.js Migration](references/code-patterns.md#nextjs-migration)
- [Vue.js Migration](references/code-patterns.md#vuejs-migration)
- [Angular Migration](references/code-patterns.md#angular-migration)
- [React Native Migration](references/code-patterns.md#react-native-migration)

**Backend:**
- [Express.js Migration](references/code-patterns.md#expressjs-migration)
- [API JWT Validation](references/code-patterns.md#backend-api-jwt-validation)

**Provider-Specific:**
- [Firebase to Auth0](references/code-patterns.md#firebase-to-auth0)
- [Supabase to Auth0](references/code-patterns.md#supabase-to-auth0)
- [Clerk to Auth0](references/code-patterns.md#clerk-to-auth0)

**After migrating code, use framework-specific skills:**
- `auth0-react` for React applications
- `auth0-nextjs` for Next.js applications
- `auth0-vue` for Vue.js applications
- `auth0-angular` for Angular applications
- `auth0-express` for Express.js applications
- `auth0-react-native` for React Native/Expo applications

---

### Step 4: Update API JWT Validation

If your API validates JWTs, update to validate Auth0 tokens.

**Key differences:**
- **Algorithm:** HS256 (symmetric) → RS256 (asymmetric)
- **Issuer:** Custom → `https://YOUR_TENANT.auth0.com/`
- **JWKS URL:** `https://YOUR_TENANT.auth0.com/.well-known/jwks.json`

**See [JWT Validation Examples](references/code-patterns.md#backend-api-jwt-validation) for:**
- Node.js / Express implementation
- Python / Flask implementation
- Key differences and migration checklist

---

## Gradual Migration Strategy

For production applications with active users, use a phased approach:

### Phase 1: Parallel Auth

Support both Auth0 and legacy provider simultaneously:

```typescript
// Support both providers during migration
const getUser = async () => {
  // Try Auth0 first
  const auth0User = await getAuth0User();
  if (auth0User) return auth0User;

  // Fall back to legacy provider
  return await getLegacyUser();
};
```

### Phase 2: New Users on Auth0

- All new signups go to Auth0
- Existing users continue on legacy provider
- Migrate users on next login (lazy migration)

### Phase 3: Forced Migration

- Prompt remaining users to "update account"
- Send password reset emails via Auth0
- Set deadline for legacy system shutdown

### Phase 4: Cleanup

- Remove legacy auth code
- Archive user export for compliance
- Update documentation

---

## Common Migration Issues

| Issue | Solution |
|-------|----------|
| Password hashes incompatible | Use Auth0 custom DB connection with lazy migration |
| Social logins don't link | Configure same social connection, users auto-link by email |
| Custom claims missing | Add claims via Auth0 Actions |
| Token format different | Update API to validate RS256 JWTs with Auth0 issuer |
| Session persistence | Auth0 uses rotating refresh tokens; update token storage |
| Users must re-login | Expected for redirect-based auth; communicate to users |

---

## Reference Documentation

### User Import
Complete guide to exporting and importing users:
- [Exporting from Common Providers](references/user-import.md#exporting-users-from-common-providers)
- [User JSON Format](references/user-import.md#auth0-user-import-format)
- [Password Hash Algorithms](references/user-import.md#password-hash-algorithms)
- [Import Methods](references/user-import.md#importing-to-auth0)
- [Monitoring & Troubleshooting](references/user-import.md#monitoring-import-progress)

### Code Migration
Before/after examples for all major frameworks:
- [React Patterns](references/code-patterns.md#react-migration)
- [Next.js Patterns](references/code-patterns.md#nextjs-migration)
- [Express Patterns](references/code-patterns.md#expressjs-migration)
- [Vue.js Patterns](references/code-patterns.md#vuejs-migration)
- [Angular Patterns](references/code-patterns.md#angular-migration)
- [React Native Patterns](references/code-patterns.md#react-native-migration)
- [API JWT Validation](references/code-patterns.md#backend-api-jwt-validation)

---

## Related Skills

### Core Integration
- `auth0-quickstart` - Initial Auth0 setup after migration

### SDK Skills
- `auth0-react` - React SPA integration
- `auth0-nextjs` - Next.js integration
- `auth0-vue` - Vue.js integration
- `auth0-angular` - Angular integration
- `auth0-express` - Express.js integration
- `auth0-react-native` - React Native/Expo integration

---

## References

- [Auth0 User Migration Documentation](https://auth0.com/docs/manage-users/user-migration)
- [Bulk User Import](https://auth0.com/docs/manage-users/user-migration/bulk-user-imports)
- [Password Hash Algorithms](https://auth0.com/docs/manage-users/user-migration/bulk-user-imports#password-hashing-algorithms)
- [Management API - User Import](https://auth0.com/docs/api/management/v2/jobs/post-users-imports)
