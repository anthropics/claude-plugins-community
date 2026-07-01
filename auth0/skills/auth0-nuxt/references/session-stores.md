# Custom Session Stores for Auth0-Nuxt

This guide covers implementing custom session stores for stateful session management in Auth0-Nuxt.

## When to Use Custom Session Stores

Use custom session stores when:
- Session data exceeds cookie size limits (4KB per chunk)
- Running in distributed/load-balanced environments
- Storing sensitive PII that shouldn't be in cookies
- Need centralized session management across services
- Implementing advanced session features (expiration, revocation)

## Stateless vs Stateful Sessions

### Stateless (Default)
- **Storage**: Encrypted, chunked cookies
- **Advantages**: Simple, no infrastructure, scales horizontally
- **Disadvantages**: 4KB size limit per chunk, data in browser
- **Use When**: Sessions are small, simple deployments

### Stateful (Custom Store)
- **Storage**: Redis, MongoDB, PostgreSQL, etc.
- **Advantages**: Unlimited size, centralized control, revocable
- **Disadvantages**: Requires infrastructure, network latency
- **Use When**: Large sessions, distributed systems, compliance requirements

## SessionStore Interface

All custom stores must implement this interface:

```typescript
interface SessionStore {
  set(identifier: string, stateData: StateData): Promise<void>;
  get(identifier: string): Promise<StateData | undefined>;
  delete(identifier: string): Promise<void>;
  deleteByLogoutToken(claims: any, options?: StoreOptions): Promise<void>;
}
```

## Redis Session Store

Complete implementation using Nitro's unstorage layer:

### 1. Create Session Store Factory

```typescript
// server/utils/session-store-factory.ts
import type { SessionStore, StateData, StoreOptions } from '@auth0/auth0-nuxt';
import type { Storage } from 'unstorage';

export class RedisSessionStore implements SessionStore {
  readonly #store: Storage<StateData>;

  constructor(store: Storage<StateData>) {
    this.#store = store;
  }

  async set(identifier: string, stateData: StateData): Promise<void> {
    await this.#store.setItem(identifier, stateData);
  }

  async get(identifier: string): Promise<StateData | undefined> {
    const result = await this.#store.getItem<StateData>(identifier);
    // Redis returns null for missing keys, map to undefined
    return result ?? undefined;
  }

  async delete(identifier: string): Promise<void> {
    await this.#store.removeItem(identifier);
  }

  async deleteByLogoutToken(claims: any, options?: StoreOptions): Promise<void> {
    // Extract session ID from logout token claims
    const sid = claims.sid;

    if (sid) {
      // Delete session by session ID
      await this.delete(sid);
    }
  }
}

export default function getSessionStoreInstance() {
  const storage = useStorage<StateData>('redis');
  return new RedisSessionStore(storage);
}
```

### 2. Configure Module

```typescript
// nuxt.config.ts
export default defineNuxtConfig({
  modules: [
    ['@auth0/auth0-nuxt', {
      sessionStoreFactoryPath: '~/server/utils/session-store-factory.ts'
    }]
  ],
  runtimeConfig: {
    auth0: {
      domain: '',
      clientId: '',
      clientSecret: '',
      sessionSecret: '',
      appBaseUrl: 'http://localhost:3000',
    },
  },
});
```

### 3. Configure Nitro Storage

```typescript
// nuxt.config.ts
export default defineNuxtConfig({
  nitro: {
    storage: {
      redis: {
        driver: 'redis',
        host: process.env.REDIS_HOST || '127.0.0.1',
        port: parseInt(process.env.REDIS_PORT || '6379'),
        password: process.env.REDIS_PASSWORD,
        db: parseInt(process.env.REDIS_DB || '0'),
      }
    }
  }
});
```

### 4. Docker Compose for Local Development

```yaml
# docker-compose.yml
version: '3.8'
services:
  redis:
    image: redis:7-alpine
    ports:
      - '6379:6379'
    volumes:
      - redis_data:/data

volumes:
  redis_data:
```

## MongoDB Session Store

Implementation using Nitro's MongoDB driver:

```typescript
// server/utils/session-store-factory.ts
import type { SessionStore, StateData, StoreOptions } from '@auth0/auth0-nuxt';
import type { Storage } from 'unstorage';

export class MongoSessionStore implements SessionStore {
  readonly #store: Storage<StateData>;

  constructor(store: Storage<StateData>) {
    this.#store = store;
  }

  async set(identifier: string, stateData: StateData): Promise<void> {
    await this.#store.setItem(identifier, stateData);
  }

  async get(identifier: string): Promise<StateData | undefined> {
    const result = await this.#store.getItem<StateData>(identifier);
    return result ?? undefined;
  }

  async delete(identifier: string): Promise<void> {
    await this.#store.removeItem(identifier);
  }

  async deleteByLogoutToken(claims: any, options?: StoreOptions): Promise<void> {
    const sid = claims.sid;
    if (sid) {
      await this.delete(sid);
    }
  }
}

export default function getSessionStoreInstance() {
  const storage = useStorage<StateData>('mongodb');
  return new MongoSessionStore(storage);
}
```

### MongoDB Nitro Configuration

```typescript
// nuxt.config.ts
export default defineNuxtConfig({
  nitro: {
    storage: {
      mongodb: {
        driver: 'mongodb',
        connectionString: process.env.MONGODB_URI || 'mongodb://localhost:27017',
        databaseName: 'auth0_sessions',
        collectionName: 'sessions',
      }
    }
  }
});
```

## PostgreSQL Session Store

Using a custom implementation with pg library:

```typescript
// server/utils/session-store-factory.ts
import type { SessionStore, StateData, StoreOptions } from '@auth0/auth0-nuxt';
import { Pool } from 'pg';

export class PostgresSessionStore implements SessionStore {
  readonly #pool: Pool;

  constructor() {
    this.#pool = new Pool({
      host: process.env.POSTGRES_HOST || 'localhost',
      port: parseInt(process.env.POSTGRES_PORT || '5432'),
      database: process.env.POSTGRES_DB || 'auth0_sessions',
      user: process.env.POSTGRES_USER,
      password: process.env.POSTGRES_PASSWORD,
    });
  }

  async set(identifier: string, stateData: StateData): Promise<void> {
    const query = `
      INSERT INTO sessions (id, data, expires_at)
      VALUES ($1, $2, NOW() + INTERVAL '1 day')
      ON CONFLICT (id) DO UPDATE SET data = $2, expires_at = NOW() + INTERVAL '1 day'
    `;
    await this.#pool.query(query, [identifier, JSON.stringify(stateData)]);
  }

  async get(identifier: string): Promise<StateData | undefined> {
    const query = `
      SELECT data FROM sessions
      WHERE id = $1 AND expires_at > NOW()
    `;
    const result = await this.#pool.query(query, [identifier]);

    if (result.rows.length === 0) {
      return undefined;
    }

    return JSON.parse(result.rows[0].data);
  }

  async delete(identifier: string): Promise<void> {
    await this.#pool.query('DELETE FROM sessions WHERE id = $1', [identifier]);
  }

  async deleteByLogoutToken(claims: any, options?: StoreOptions): Promise<void> {
    const sid = claims.sid;
    if (sid) {
      await this.delete(sid);
    }
  }
}

export default function getSessionStoreInstance() {
  return new PostgresSessionStore();
}
```

### PostgreSQL Schema

```sql
CREATE TABLE sessions (
  id VARCHAR(255) PRIMARY KEY,
  data JSONB NOT NULL,
  expires_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_sessions_expires_at ON sessions(expires_at);
```

## Back-Channel Logout Implementation

Proper implementation of `deleteByLogoutToken`:

```typescript
async deleteByLogoutToken(claims: any, options?: StoreOptions): Promise<void> {
  // Claims from the logout_token JWT
  const sid = claims.sid; // Session ID
  const sub = claims.sub; // User ID

  if (sid) {
    // Delete specific session by session ID
    await this.delete(sid);
  } else if (sub) {
    // Delete all sessions for the user
    // Implementation depends on your storage
    // This example assumes you track sessions by user
    await this.deleteAllForUser(sub);
  }
}
```

## Session Expiration

Implement TTL (Time-To-Live) in your session store:

```typescript
// Redis with TTL
async set(identifier: string, stateData: StateData): Promise<void> {
  await this.#store.setItem(identifier, stateData, {
    ttl: 86400, // 24 hours in seconds
  });
}

// PostgreSQL with automatic cleanup
// Run this periodically (cronjob or Nitro task)
async cleanup(): Promise<void> {
  await this.#pool.query('DELETE FROM sessions WHERE expires_at < NOW()');
}
```

## Testing Your Session Store

```typescript
// test/session-store.test.ts
import { describe, it, expect } from 'vitest';
import getSessionStoreInstance from '~/server/utils/session-store-factory';

describe('Session Store', () => {
  const store = getSessionStoreInstance();
  const testData = {
    user: { sub: 'test-user' },
    idToken: 'test-token',
    tokenSets: [],
    internal: { sid: 'test-session', createdAt: Date.now() },
  };

  it('should store and retrieve session', async () => {
    await store.set('test-id', testData);
    const result = await store.get('test-id');
    expect(result).toEqual(testData);
  });

  it('should delete session', async () => {
    await store.set('test-id-2', testData);
    await store.delete('test-id-2');
    const result = await store.get('test-id-2');
    expect(result).toBeUndefined();
  });

  it('should handle logout token', async () => {
    await store.set('test-id-3', testData);
    await store.deleteByLogoutToken({ sid: 'test-session' });
    const result = await store.get('test-id-3');
    expect(result).toBeUndefined();
  });
});
```

## Performance Considerations

1. **Connection Pooling**: Always use connection pools for database connections
2. **Caching**: Consider caching frequently accessed sessions
3. **Indexing**: Add indexes on session ID and expiration columns
4. **TTL**: Implement automatic expiration to prevent storage bloat
5. **Serialization**: Use efficient serialization (JSON, MessagePack)

## Security Considerations

1. **Encryption**: Session data is already encrypted by Auth0-Nuxt
2. **Access Control**: Restrict database access to your application only
3. **Network Security**: Use TLS for database connections
4. **Secrets Management**: Store credentials in environment variables
5. **Audit Logging**: Log session access for compliance

## Migration from Stateless to Stateful

1. Deploy stateful configuration alongside stateless
2. New sessions use stateful store
3. Old cookie-based sessions continue working
4. Gradually phase out cookie sessions as they expire
5. Monitor cookie size metrics
