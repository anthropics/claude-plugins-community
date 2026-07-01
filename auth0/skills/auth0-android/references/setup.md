# Auth0 Android Setup Guide

> **Agent instruction:** Before providing version numbers, fetch the latest release:
> `gh api repos/auth0/Auth0.Android/releases/latest --jq '.tag_name'`
> Replace `{LATEST_VERSION}` in all dependency lines with the result.

## Setup Overview

1. Add SDK dependency to `build.gradle`
2. Configure Auth0 (automatic inline script or manual credentials)
3. Add manifest placeholders and INTERNET permission (post-setup)

## Auth0 Configuration

> **Agent instruction:** First, check whether the user prompt already includes both Auth0 **Client ID** and **Domain**.
> - If both are provided, skip the setup-choice question and proceed directly to **Manual Setup (User-Provided Credentials)** using those values.
> - If either value is missing, ask the user:
>   - Question: "How would you like to configure Auth0 for this project?"
>   - Options: "Automatic setup (Recommended) — Auth0 CLI creates the app and writes credentials to strings.xml" / "Manual setup — I'll provide my Client ID and Domain"
>
> Follow the matching section below based on their choice.

### Automatic Setup

Below automates the setup. Inform the user that Auth0 credentials will be written to `strings.xml`.

**Before running any part of this setup that writes to `strings.xml`, you MUST ask the user for explicit confirmation.** Follow the steps below precisely.

#### Step 1: Check for existing strings.xml and confirm with user

Before writing credentials, check whether a `strings.xml` already exists:

```bash
test -f app/src/main/res/values/strings.xml && echo "STRINGS_EXISTS" || echo "STRINGS_NOT_FOUND"
```

Then ask the user for explicit confirmation before proceeding — do not continue until the user confirms:

- If `strings.xml` exists, ask:
  - Question: "A `strings.xml` file already exists. This setup will add or update the Auth0 credential entries (`com_auth0_client_id`, `com_auth0_domain`, `com_auth0_scheme`) without modifying other entries. Do you want to proceed?"
  - Options: "Yes, update existing strings.xml" / "No, I'll update it manually"

- If `strings.xml` does **not** exist, ask:
  - Question: "This setup will create `app/src/main/res/values/strings.xml` with Auth0 credentials (`com_auth0_client_id`, `com_auth0_domain`, `com_auth0_scheme`). Do you want to proceed?"
  - Options: "Yes, create strings.xml" / "No, I'll configure it manually"

**Do not proceed with writing to strings.xml unless the user selects the confirmation option.**

#### Step 2: Run automated setup (only after confirmation)

```bash
#!/bin/bash

PROJECT_PATH="${1:-$PWD}"
SCHEME="demo"

# Install Auth0 CLI
if ! command -v auth0 &> /dev/null; then
  [[ "$OSTYPE" == "darwin"* ]] && brew install auth0/auth0-cli/auth0 || \
  curl -sSfL https://raw.githubusercontent.com/auth0/auth0-cli/main/install.sh | sh -s -- -b /usr/local/bin
fi

# Login
auth0 login 2>/dev/null || auth0 login

# Find build.gradle / build.gradle.kts
if [ -f "$PROJECT_PATH/app/build.gradle" ]; then
  GRADLE_FILE="$PROJECT_PATH/app/build.gradle"
elif [ -f "$PROJECT_PATH/app/build.gradle.kts" ]; then
  GRADLE_FILE="$PROJECT_PATH/app/build.gradle.kts"
else
  echo "❌ No app/build.gradle or app/build.gradle.kts found in $PROJECT_PATH"
  exit 1
fi

# Extract applicationId
PACKAGE_NAME=$(grep -E 'applicationId\s*=?\s*"[^"]*"' "$GRADLE_FILE" | grep -oE '"[^"]*"' | tr -d '"' | head -1)
if [ -z "$PACKAGE_NAME" ]; then
  echo "❌ Could not find applicationId in $GRADLE_FILE"
  exit 1
fi

# List existing apps and prompt to pick or create
auth0 apps list
read -p "Enter app ID (or press Enter to create a new one): " APP_ID

if [ -z "$APP_ID" ]; then
  DOMAIN=$(auth0 tenants list --csv --no-input 2>/dev/null | grep '→' | cut -d',' -f2 | tr -d ' ')
  CALLBACK_URL="${SCHEME}://${DOMAIN}/android/${PACKAGE_NAME}/callback"
  CLIENT_JSON=$(auth0 apps create \
    --name "${PACKAGE_NAME}-android" \
    --type native \
    --auth-method none \
    --callbacks "$CALLBACK_URL" \
    --logout-urls "$CALLBACK_URL" \
    --json \
    --no-input)
  CLIENT_ID=$(echo "$CLIENT_JSON" | grep -o '"client_id":"[^"]*' | cut -d'"' -f4)
else
  CLIENT_ID=$(auth0 apps show "$APP_ID" --json | grep -o '"client_id":"[^"]*' | cut -d'"' -f4)
  DOMAIN=$(auth0 apps show "$APP_ID" --json | grep -o '"domain":"[^"]*' | cut -d'"' -f4)
  CALLBACK_URL="${SCHEME}://${DOMAIN}/android/${PACKAGE_NAME}/callback"
fi

# Check / create database connection
CONNECTIONS_JSON=$(auth0 api get connections --no-input 2>/dev/null || echo "[]")
CONNECTION_ID=$(echo "$CONNECTIONS_JSON" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for c in data:
    if c.get('name') == 'Username-Password-Authentication':
        print(c['id'])
        break
" 2>/dev/null)
ENABLED_CLIENTS=$(echo "$CONNECTIONS_JSON" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for c in data:
    if c.get('name') == 'Username-Password-Authentication':
        print(json.dumps(c.get('enabled_clients', [])))
        break
" 2>/dev/null)

if [ -z "$CONNECTION_ID" ]; then
  auth0 api post connections \
    --data "{\"strategy\":\"auth0\",\"name\":\"Username-Password-Authentication\",\"enabled_clients\":[\"$CLIENT_ID\"]}" \
    --no-input > /dev/null
else
  UPDATED_CLIENTS=$(echo "$ENABLED_CLIENTS" | python3 -c "
import sys, json
clients = json.load(sys.stdin)
if '$CLIENT_ID' not in clients:
    clients.append('$CLIENT_ID')
print(json.dumps(clients))
")
  auth0 api patch "connections/$CONNECTION_ID" \
    --data "{\"enabled_clients\":$UPDATED_CLIENTS}" \
    --no-input > /dev/null
fi

# Write / update strings.xml
STRINGS_FILE="$PROJECT_PATH/app/src/main/res/values/strings.xml"
mkdir -p "$(dirname "$STRINGS_FILE")"

python3 << PYEOF
import re, os

path = "$STRINGS_FILE"
entries = {
    'com_auth0_client_id': '$CLIENT_ID',
    'com_auth0_domain': '$DOMAIN',
    'com_auth0_scheme': '$SCHEME',
}

content = open(path).read() if os.path.exists(path) else ''

if '<resources' in content:
    for key, value in entries.items():
        pattern = re.compile(r'<string\s+name="' + re.escape(key) + r'"[^>]*>[\s\S]*?</string>')
        replacement = f'<string name="{key}">{value}</string>'
        if pattern.search(content):
            content = pattern.sub(replacement, content)
        else:
            content = content.replace('</resources>', f'    <string name="{key}">{value}</string>\n</resources>')
else:
    lines = ['    <string name="app_name">My App</string>']
    lines += [f'    <string name="{k}">{v}</string>' for k, v in entries.items()]
    content = '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n' + '\n'.join(lines) + '\n</resources>\n'

with open(path, 'w') as f:
    f.write(content)
PYEOF

echo "✅ Auth0 credentials written to $STRINGS_FILE"
```

After the script runs, proceed to **Post-Setup Steps** below.

### Manual Setup (User-Provided Credentials)

> **Agent instruction:** Ask the user to provide their Auth0 **Client ID** and **Domain**.
>
> **Note:** For native Android applications, Domain and Client ID are public configuration values (compiled into the APK and visible to anyone who decompiles it). They are NOT secrets and do not grant access without the user's credentials. No client secret is used.
>
> Once the user provides values, write them directly to `strings.xml` without displaying them back in conversation output:
> ```xml
> <string name="com_auth0_client_id">USER_PROVIDED_CLIENT_ID</string>
> <string name="com_auth0_domain">USER_PROVIDED_DOMAIN</string>
> <string name="com_auth0_scheme">demo</string>
> ```
> Remind the user to configure callback URLs in the Auth0 Dashboard:
> `demo://{DOMAIN}/android/{APPLICATION_ID}/callback`
> (add to both **Allowed Callback URLs** and **Allowed Logout URLs**).
>
> After updating strings.xml, proceed to **Post-Setup Steps** below.

### Post-Setup Steps (Required for Both Paths)

> **Agent instruction:** After either automatic or manual Auth0 configuration, the agent MUST apply the following changes to the project:
>
> 1. **Add manifest placeholders** to `app/build.gradle` (or `app/build.gradle.kts`) inside the `defaultConfig` block, if not already present:
>    - Groovy (`build.gradle`):
>      ```gradle
>      manifestPlaceholders = [
>          auth0Domain: "@string/com_auth0_domain",
>          auth0Scheme: "@string/com_auth0_scheme"
>      ]
>      ```
>    - Kotlin DSL (`build.gradle.kts`):
>      ```kotlin
>      manifestPlaceholders += mapOf(
>          "auth0Domain" to "@string/com_auth0_domain",
>          "auth0Scheme" to "@string/com_auth0_scheme"
>      )
>      ```
>
> 2. **Add INTERNET permission** to `AndroidManifest.xml` if not already present:
>    ```xml
>    <uses-permission android:name="android.permission.INTERNET" />
>    ```
>
> 3. **Build the project** to confirm everything compiles:
>    ```bash
>    ./gradlew assembleDebug
>    ```

## SDK Installation

Add the dependency to your module's `build.gradle`:

```gradle
dependencies {
    implementation 'com.auth0.android:auth0:{LATEST_VERSION}'
}
```

Ensure Java 8 compatibility in your `build.gradle`:

```gradle
android {
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = '1.8'
    }
}
```

## Android App Links (Recommended for Production)

> **Note:** The automatic setup script and manual setup default to a custom scheme (`demo://`) for simplicity. App Links with `https://` are recommended for production apps. To switch, update `com_auth0_scheme` to `https` in `strings.xml` and update your callback URL in the Auth0 Dashboard to `https://YOUR_AUTH0_DOMAIN/android/YOUR_APP_PACKAGE_NAME/callback`.

For the `https://` scheme, Android uses App Links for deeper integration:

1. **Digital Asset Links**: Create a `assetlinks.json` file on your Auth0 domain
   - Auth0 manages this automatically for you
   - Enables deep link routing without user prompts

2. **Auto-Verify**: Add to `build.gradle`:
   ```gradle
   android {
       defaultConfig {
           // The android:autoVerify attribute is added automatically for https schemes
       }
   }
   ```

The SDK automatically uses App Links when `com_auth0_scheme` is set to `https` in `strings.xml`.

## Custom Scheme (Alternative)

If you need a custom scheme instead of `https://`:

1. Update `strings.xml` with your custom scheme:
   ```xml
   <string name="com_auth0_scheme">myapp</string>
   ```

   The manifest placeholder already references this via `@string/com_auth0_scheme`.

2. Update callback URL in Auth0 Dashboard:
   ```
   myapp://YOUR_AUTH0_DOMAIN/android/YOUR_APP_PACKAGE_NAME/callback
   ```

3. In your code when logging out, use the same scheme:
   ```kotlin
   WebAuthProvider.logout(account)
       .withScheme(getString(R.string.com_auth0_scheme))
       .start(this, callback)
   ```

**Important**: Android requires scheme names to be lowercase.

## ProGuard/R8

The Auth0 Android SDK includes ProGuard/R8 rules automatically. You don't need to add any manual configuration. The library's `proguard-rules.pro` is included in the AAR file and will be merged into your app's build.

If you encounter obfuscation issues:

1. Disable obfuscation for Auth0 classes (in `proguard-rules.pro`):
   ```
   -keep class com.auth0.** { *; }
   ```

2. Or rebuild with debugging enabled temporarily:
   ```gradle
   buildTypes {
       debug {
           debuggable true
           minifyEnabled false
       }
   }
   ```
