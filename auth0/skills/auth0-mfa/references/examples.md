# MFA Step-Up Authentication Examples

Framework-specific code examples for implementing step-up authentication.

---

## React

### Basic Example

```typescript
import { useAuth0 } from '@auth0/auth0-react';

function SensitiveAction() {
  const { getAccessTokenSilently, getIdTokenClaims } = useAuth0();

  const requireMFA = async () => {
    // Check if user already completed MFA
    const claims = await getIdTokenClaims();
    const amr = claims?.amr || [];

    if (!amr.includes('mfa')) {
      // Request MFA via step-up authentication
      await getAccessTokenSilently({
        authorizationParams: {
          acr_values: 'http://schemas.openid.net/pape/policies/2007/06/multi-factor',
          max_age: 0, // Force re-authentication
        },
      });
    }

    // User has completed MFA, proceed with sensitive action
    return performSensitiveAction();
  };

  return (
    <button onClick={requireMFA}>
      Transfer Funds (Requires MFA)
    </button>
  );
}
```

### Custom Hook

```typescript
import { useAuth0 } from '@auth0/auth0-react';
import { useCallback, useState } from 'react';

interface StepUpOptions {
  maxAge?: number;
}

export function useStepUpAuth() {
  const { getAccessTokenSilently, getIdTokenClaims, loginWithRedirect } = useAuth0();
  const [isVerifying, setIsVerifying] = useState(false);

  const hasMFA = useCallback(async (): Promise<boolean> => {
    const claims = await getIdTokenClaims();
    const amr = claims?.amr || [];
    return amr.includes('mfa');
  }, [getIdTokenClaims]);

  const requireMFA = useCallback(async (options: StepUpOptions = {}) => {
    setIsVerifying(true);
    try {
      const mfaCompleted = await hasMFA();

      if (!mfaCompleted) {
        // Try silent step-up first
        try {
          await getAccessTokenSilently({
            authorizationParams: {
              acr_values: 'http://schemas.openid.net/pape/policies/2007/06/multi-factor',
              max_age: options.maxAge ?? 0,
            },
            cacheMode: 'off',
          });
        } catch {
          // Silent failed, redirect to MFA
          await loginWithRedirect({
            authorizationParams: {
              acr_values: 'http://schemas.openid.net/pape/policies/2007/06/multi-factor',
              max_age: options.maxAge ?? 0,
            },
          });
          return false;
        }
      }

      return true;
    } finally {
      setIsVerifying(false);
    }
  }, [getAccessTokenSilently, loginWithRedirect, hasMFA]);

  return { requireMFA, hasMFA, isVerifying };
}

// Usage
function TransferFunds() {
  const { requireMFA, isVerifying } = useStepUpAuth();

  const handleTransfer = async () => {
    const verified = await requireMFA();
    if (verified) {
      // Proceed with transfer
    }
  };

  return (
    <button onClick={handleTransfer} disabled={isVerifying}>
      {isVerifying ? 'Verifying...' : 'Transfer Funds'}
    </button>
  );
}
```

---

## Next.js (App Router)

### API Route

```typescript
// app/api/sensitive/route.ts
import { getSession, withApiAuthRequired } from '@auth0/nextjs-auth0';
import { NextResponse } from 'next/server';

export const POST = withApiAuthRequired(async function handler(req) {
  const session = await getSession();

  // Check if MFA was completed
  const amr = session?.user?.amr || [];

  if (!amr.includes('mfa')) {
    return NextResponse.json(
      { error: 'MFA required', code: 'mfa_required' },
      { status: 403 }
    );
  }

  // Proceed with sensitive operation
  return NextResponse.json({ success: true });
});
```

### Client Component

```typescript
// app/transfer/page.tsx
'use client';

import { useUser } from '@auth0/nextjs-auth0/client';
import { useRouter } from 'next/navigation';

export default function TransferPage() {
  const { user } = useUser();
  const router = useRouter();

  const handleTransfer = async () => {
    const response = await fetch('/api/sensitive', { method: 'POST' });

    if (response.status === 403) {
      const { code } = await response.json();
      if (code === 'mfa_required') {
        // Redirect to login with MFA required
        router.push('/api/auth/login?acr_values=http://schemas.openid.net/pape/policies/2007/06/multi-factor');
        return;
      }
    }

    // Success
  };

  return <button onClick={handleTransfer}>Transfer Funds</button>;
}
```

---

## Vue.js

```typescript
<script setup lang="ts">
import { useAuth0 } from '@auth0/auth0-vue';
import { ref } from 'vue';

const { getAccessTokenSilently, getIdTokenClaims, loginWithRedirect } = useAuth0();
const isVerifying = ref(false);

const hasMFA = async (): Promise<boolean> => {
  const claims = await getIdTokenClaims();
  const amr = claims?.amr || [];
  return amr.includes('mfa');
};

const requireMFA = async () => {
  isVerifying.value = true;
  try {
    if (!(await hasMFA())) {
      try {
        await getAccessTokenSilently({
          authorizationParams: {
            acr_values: 'http://schemas.openid.net/pape/policies/2007/06/multi-factor',
            max_age: 0,
          },
        });
      } catch {
        await loginWithRedirect({
          authorizationParams: {
            acr_values: 'http://schemas.openid.net/pape/policies/2007/06/multi-factor',
          },
        });
        return false;
      }
    }
    return true;
  } finally {
    isVerifying.value = false;
  }
};

const handleSensitiveAction = async () => {
  if (await requireMFA()) {
    // Proceed with sensitive action
    console.log('MFA verified, proceeding...');
  }
};
</script>

<template>
  <button @click="handleSensitiveAction" :disabled="isVerifying">
    {{ isVerifying ? 'Verifying...' : 'Transfer Funds' }}
  </button>
</template>
```

---

## Angular

```typescript
import { Component, inject } from '@angular/core';
import { AuthService } from '@auth0/auth0-angular';
import { firstValueFrom } from 'rxjs';

@Component({
  selector: 'app-sensitive-action',
  template: `
    <button (click)="handleSensitiveAction()" [disabled]="isVerifying">
      {{ isVerifying ? 'Verifying...' : 'Transfer Funds' }}
    </button>
  `
})
export class SensitiveActionComponent {
  private auth = inject(AuthService);
  isVerifying = false;

  private async hasMFA(): Promise<boolean> {
    const claims = await firstValueFrom(this.auth.idTokenClaims$);
    const amr = (claims as any)?.amr || [];
    return amr.includes('mfa');
  }

  async handleSensitiveAction() {
    this.isVerifying = true;
    try {
      if (!(await this.hasMFA())) {
        // Request MFA
        this.auth.loginWithRedirect({
          authorizationParams: {
            acr_values: 'http://schemas.openid.net/pape/policies/2007/06/multi-factor',
            max_age: 0,
          },
        });
        return;
      }

      // MFA verified, proceed
      console.log('MFA verified, proceeding...');
    } finally {
      this.isVerifying = false;
    }
  }
}
```
