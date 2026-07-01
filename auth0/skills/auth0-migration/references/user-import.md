# User Export and Import Guide

Detailed guide for exporting users from existing auth providers and importing them to Auth0.

---

## Exporting Users from Common Providers

### Firebase

**Via Firebase Console:**
1. Go to Authentication → Users
2. Click "..." menu → Export users
3. Downloads JSON file

**Via Firebase CLI:**
```bash
firebase auth:export users.json --format=JSON
```

**Firebase user format:**
```json
{
  "users": [
    {
      "localId": "user123",
      "email": "user@example.com",
      "emailVerified": true,
      "passwordHash": "base64-encoded-hash",
      "salt": "base64-encoded-salt",
      "createdAt": "1234567890000"
    }
  ]
}
```

---

### AWS Cognito

**Via AWS CLI:**
```bash
aws cognito-idp list-users \
  --user-pool-id us-east-1_ABC123 \
  --output json > users.json
```

**Via Node.js Script:**
```javascript
const AWS = require('aws-sdk');
const cognito = new AWS.CognitoIdentityServiceProvider();

async function exportUsers() {
  let users = [];
  let paginationToken;

  do {
    const response = await cognito.listUsers({
      UserPoolId: 'us-east-1_ABC123',
      PaginationToken: paginationToken
    }).promise();

    users = users.concat(response.Users);
    paginationToken = response.PaginationToken;
  } while (paginationToken);

  return users;
}
```

---

### Supabase

**Via Supabase SQL:**
```sql
-- Connect to Supabase database
SELECT
  id,
  email,
  email_confirmed_at IS NOT NULL as email_verified,
  encrypted_password,
  created_at,
  raw_user_meta_data
FROM auth.users;
```

**Export to JSON:**
```bash
psql $DATABASE_URL -c "COPY (SELECT row_to_json(t) FROM (
  SELECT id, email, encrypted_password, created_at
  FROM auth.users
) t) TO STDOUT" > users.json
```

---

### Custom Database

**Example SQL query:**
```sql
SELECT
  id,
  email,
  email_verified,
  password_hash,
  created_at,
  last_login,
  metadata
FROM users
WHERE active = true;
```

**Export script (Node.js):**
```javascript
const { Pool } = require('pg');

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

async function exportUsers() {
  const result = await pool.query(`
    SELECT
      id,
      email,
      email_verified,
      password_hash,
      created_at
    FROM users
  `);

  return result.rows.map(row => ({
    email: row.email,
    email_verified: row.email_verified,
    user_id: row.id,
    created_at: row.created_at.toISOString()
  }));
}
```

---

## Required User Data

### Minimum Required Fields

| Field | Required | Description |
|-------|----------|-------------|
| `email` | ✅ Yes | User's email address |
| `email_verified` | ✅ Yes | Whether email is verified (true/false) |
| `user_id` | No | Original user ID (preserved for reference) |
| `password` | No* | Only if using password hash |
| `custom_password_hash` | No* | Password hash with algorithm |

*Either `password` (plain text, not recommended) or `custom_password_hash` required for password-based users.

### Optional Fields

| Field | Description |
|-------|-------------|
| `given_name` | First name |
| `family_name` | Last name |
| `name` | Full name |
| `nickname` | Display name |
| `picture` | Profile picture URL |
| `created_at` | Account creation timestamp |
| `user_metadata` | Custom user data (editable by user) |
| `app_metadata` | Custom app data (not editable by user) |

---

## Auth0 User Import Format

### JSON Structure

```json
[
  {
    "email": "user@example.com",
    "email_verified": true,
    "user_id": "original-id-from-old-system",
    "custom_password_hash": {
      "algorithm": "bcrypt",
      "hash": "$2a$10$abcdefghijklmnopqrstuv"
    },
    "given_name": "John",
    "family_name": "Doe",
    "name": "John Doe",
    "nickname": "johnd",
    "picture": "https://example.com/avatar.jpg",
    "user_metadata": {
      "hobby": "reading",
      "plan": "premium",
      "migrated_from": "firebase"
    },
    "app_metadata": {
      "roles": ["admin"],
      "permissions": ["read:users", "write:posts"]
    }
  }
]
```

---

## Password Hash Algorithms

### Supported Algorithms

Auth0 supports these password hashing algorithms:

| Algorithm | Common Usage | Example |
|-----------|--------------|---------|
| `bcrypt` | Node.js, Ruby, PHP, Python | `$2a$10$...` |
| `argon2` | Modern apps, security-focused | `$argon2id$v=19$m=65536...` |
| `pbkdf2` | Python, Java | Requires iterations, key length |
| `sha256` | Legacy systems | Not recommended (weak) |
| `sha512` | Legacy systems | Not recommended (weak) |
| `md5` | Very old systems | Not recommended (very weak) |

### bcrypt Format

```json
{
  "custom_password_hash": {
    "algorithm": "bcrypt",
    "hash": "$2a$10$abcdefghijklmnopqrstuv"
  }
}
```

**The hash includes:**
- `$2a$` - bcrypt identifier
- `10` - cost factor
- Rest - salt + hash

---

### argon2 Format

```json
{
  "custom_password_hash": {
    "algorithm": "argon2",
    "hash": {
      "encoded": "$argon2id$v=19$m=65536,t=3,p=4$salt$hash"
    }
  }
}
```

---

### PBKDF2 Format

```json
{
  "custom_password_hash": {
    "algorithm": "pbkdf2",
    "hash": {
      "value": "base64-encoded-hash",
      "encoding": "base64",
      "key_length": 32,
      "iterations": 10000,
      "digest": "sha256"
    }
  }
}
```

---

### SHA-256/SHA-512 Format

```json
{
  "custom_password_hash": {
    "algorithm": "sha256",
    "hash": {
      "value": "hex-encoded-hash",
      "encoding": "hex"
    }
  }
}
```

**Note:** Add salt if your system used salted hashes:
```json
{
  "custom_password_hash": {
    "algorithm": "sha256",
    "hash": {
      "value": "hex-encoded-hash",
      "encoding": "hex"
    },
    "salt": {
      "value": "hex-encoded-salt",
      "encoding": "hex",
      "position": "prefix"
    }
  }
}
```

---

## Importing to Auth0

### Method 1: Auth0 Dashboard

**Steps:**
1. Go to Auth0 Dashboard
2. Navigate to **Authentication → Database → [Your Connection]**
3. Click **Users** tab
4. Click **Import Users** button
5. Upload your JSON file
6. Review and confirm

**Limitations:**
- File size: Max 500KB per upload
- Users per file: Recommended max 10,000

---

### Method 2: Auth0 CLI

**Prerequisites:**
```bash
# Install Auth0 CLI
brew install auth0/auth0-cli/auth0

# Login
auth0 login
```

**Import users:**
```bash
# Get connection ID
auth0 connections list

# Import users
auth0 api post "jobs/users-imports" \
  --data "connection_id=con_ABC123" \
  --data "users=@users.json"
```

**Check import status:**
```bash
auth0 api get "jobs/{job-id}"
```

---

### Method 3: Management API

**Using curl:**
```bash
curl -X POST "https://YOUR_DOMAIN.auth0.com/api/v2/jobs/users-imports" \
  -H "Authorization: Bearer YOUR_MGMT_API_TOKEN" \
  -H "Content-Type: multipart/form-data" \
  -F "users=@users.json" \
  -F "connection_id=con_ABC123" \
  -F "upsert=false" \
  -F "send_completion_email=true"
```

**Using Node.js:**
```javascript
const { ManagementClient } = require('auth0');
const fs = require('fs');

const management = new ManagementClient({
  domain: process.env.AUTH0_DOMAIN,
  clientId: process.env.AUTH0_CLIENT_ID,
  clientSecret: process.env.AUTH0_CLIENT_SECRET
});

async function importUsers() {
  const users = fs.readFileSync('users.json');

  const job = await management.importUsers({
    connection_id: 'con_ABC123',
    users: users,
    upsert: false,
    send_completion_email: true
  });

  console.log(`Import job created: ${job.id}`);
  return job;
}
```

---

## Import Options

### upsert

- `true`: Update existing users, create new ones
- `false` (default): Only create new users, skip existing

**When to use:**
- `upsert=true`: Re-running imports with updated data
- `upsert=false`: Initial migration, avoid accidental overwrites

---

### send_completion_email

- `true`: Email you when import completes
- `false`: No email notification

**Useful for:** Large imports that take time

---

### external_id

Add to track which users were imported:

```json
{
  "email": "user@example.com",
  "external_id": "firebase:user123"
}
```

---

## Monitoring Import Progress

### Check Job Status

```bash
# Via CLI
auth0 api get "jobs/{job-id}"

# Via Management API
curl "https://YOUR_DOMAIN.auth0.com/api/v2/jobs/{job-id}" \
  -H "Authorization: Bearer YOUR_MGMT_API_TOKEN"
```

**Response:**
```json
{
  "id": "job_abc123",
  "type": "users_import",
  "status": "processing",
  "created_at": "2025-01-20T10:00:00.000Z",
  "connection_id": "con_ABC123",
  "summary": {
    "total": 1000,
    "inserted": 950,
    "updated": 0,
    "failed": 50
  }
}
```

**Status values:**
- `pending`: Job queued
- `processing`: Import in progress
- `completed`: Import finished successfully
- `failed`: Import failed

---

### Download Error Report

If import has failures:

```bash
# Get errors file URL
auth0 api get "jobs/{job-id}/errors"

# Download errors
curl "https://YOUR_DOMAIN.auth0.com/api/v2/jobs/{job-id}/errors" \
  -H "Authorization: Bearer YOUR_MGMT_API_TOKEN" \
  -o import-errors.json
```

**Error format:**
```json
[
  {
    "user": {
      "email": "invalid@example"
    },
    "errors": [
      {
        "code": "INVALID_EMAIL",
        "message": "Email format is invalid"
      }
    ]
  }
]
```

---

## Common Import Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `INVALID_EMAIL` | Email format invalid | Validate and fix email format |
| `DUPLICATE_USER` | User already exists | Use `upsert=true` or skip |
| `INVALID_PASSWORD_HASH` | Hash format incorrect | Check algorithm and format |
| `MISSING_REQUIRED_FIELD` | Required field missing | Add email and email_verified |
| `CONNECTION_NOT_FOUND` | Invalid connection ID | Verify connection ID |
| `FILE_TOO_LARGE` | File exceeds limit | Split into smaller files |
| `INVALID_JSON` | JSON syntax error | Validate JSON format |

---

## Best Practices

### Prepare Your Data

1. **Validate emails:** Remove invalid/duplicate emails
2. **Verify JSON:** Use JSON validator before upload
3. **Test with small batch:** Import 10-100 users first
4. **Backup original data:** Keep copy of export

### Split Large Imports

```bash
# Split into 5000-user chunks
split -l 5000 users.json users-chunk-

# Import each chunk
for file in users-chunk-*; do
  auth0 api post "jobs/users-imports" \
    --data "connection_id=con_ABC123" \
    --data "users=@$file"
done
```

### Add Migration Metadata

Track migration for each user:

```json
{
  "email": "user@example.com",
  "user_metadata": {
    "migrated": true,
    "migrated_at": "2025-01-20T10:00:00.000Z",
    "migrated_from": "firebase",
    "original_id": "firebase-user-123"
  }
}
```

---

## Post-Import Verification

### Check User Count

```bash
# Get total users in Auth0
auth0 users list --number 1

# Or via API
curl "https://YOUR_DOMAIN.auth0.com/api/v2/users?per_page=1" \
  -H "Authorization: Bearer YOUR_MGMT_API_TOKEN" \
  | jq '.total'
```

### Test Login

```bash
# Test user can login
auth0 test login --client-id YOUR_CLIENT_ID
```

### Verify Password Hashes Work

Pick random users and attempt login to verify password hashes imported correctly.

---

## References

- [Auth0 Bulk User Import](https://auth0.com/docs/manage-users/user-migration/bulk-user-imports)
- [Password Hash Algorithms](https://auth0.com/docs/manage-users/user-migration/bulk-user-imports#password-hashing-algorithms)
- [Management API - User Import Job](https://auth0.com/docs/api/management/v2/jobs/post-users-imports)
- [User Import Best Practices](https://auth0.com/docs/manage-users/user-migration/bulk-user-imports#best-practices)
