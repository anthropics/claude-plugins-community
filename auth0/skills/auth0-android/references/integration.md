# Auth0 Android Integration Patterns

> **Agent instruction:** Before creating new UI elements (buttons, click handlers), search the user's project for existing login/logout/sign-in/sign-out click handlers. If found, hook Auth0 code into the existing handlers without modifying the UI. Only create new buttons if no existing handlers are found.

## Web Auth Login

Use the browser-based Web Auth flow for the most secure login experience:

```kotlin
import com.auth0.android.Auth0
import com.auth0.android.provider.WebAuthProvider
import com.auth0.android.callback.Callback
import com.auth0.android.result.Credentials
import com.auth0.android.authentication.AuthenticationException

val account = Auth0.getInstance(context)

WebAuthProvider.login(account)
    .withScheme(getString(R.string.com_auth0_scheme))
    .withScope("openid profile email offline_access")
    .withAudience("https://api.example.com")  // Optional: your API audience
    .withOrganization("org_abc123")  // Optional: for organization login
    .start(context, object : Callback<Credentials, AuthenticationException> {
        override fun onSuccess(result: Credentials) {
            // User authenticated successfully
            val idToken = result.idToken
            val accessToken = result.accessToken
            val refreshToken = result.refreshToken
            val expiresAt = result.expiresAt

            // Store credentials securely (see Credential Storage section)
        }

        override fun onFailure(error: AuthenticationException) {
            // Handle authentication failure
            when {
                error.isBrowserAppNotAvailable -> {
                    // No browser available on device
                }
                error.isAuthenticationCanceled -> {
                    // User canceled the login
                }
                else -> {
                    // Other authentication error
                    Log.e("Auth0", error.message.orEmpty())
                }
            }
        }
    })
```

**Options**:
- `.withScheme()` — URL scheme matching `com_auth0_scheme` in strings.xml (required)
- `.withScope()` — Requested scopes (space-separated)
- `.withAudience()` — Your API identifier for the access token
- `.withOrganization()` — Organization ID or name for SSO
- `.withConnection()` — Force a specific connection (e.g., "google-oauth2")
- `.withPrompt()` — Force login prompt: `"login"` or `"none"`

## Web Auth Logout

Log out the user and clear their session:

```kotlin
WebAuthProvider.logout(account)
    .withScheme(getString(R.string.com_auth0_scheme))  // Match your configured scheme
    .start(this, object : Callback<Void?, AuthenticationException> {
        override fun onSuccess(result: Void) {
            // User logged out successfully
            // Clear your app's local state
        }

        override fun onFailure(error: AuthenticationException) {
            // Logout failed
            Log.e("Auth0", "Logout error: ${error.message}")
        }
    })
```

After logout, clear stored credentials:

```kotlin
val authentication = AuthenticationAPIClient(account)
val storage = SharedPreferencesStorage(this)
val manager = SecureCredentialsManager(this, authentication, storage)
manager.clearCredentials()
```

## Credential Storage

Store and retrieve credentials securely using `SecureCredentialsManager`:

```kotlin
import com.auth0.android.authentication.AuthenticationAPIClient
import com.auth0.android.authentication.storage.CredentialsManagerException
import com.auth0.android.authentication.storage.SecureCredentialsManager
import com.auth0.android.authentication.storage.SharedPreferencesStorage
import com.auth0.android.callback.Callback
import com.auth0.android.result.Credentials

val authentication = AuthenticationAPIClient(account)
val storage = SharedPreferencesStorage(context)
val manager = SecureCredentialsManager(context, authentication, storage)

// Save credentials after login
manager.saveCredentials(credentials)

// Check if valid credentials exist
if (manager.hasValidCredentials()) {
    // Valid credentials stored
}

// Retrieve credentials (auto-refreshes if needed)
manager.getCredentials(object : Callback<Credentials, CredentialsManagerException> {
    override fun onSuccess(result: Credentials) {
        val accessToken = result.accessToken
        val idToken = result.idToken
        // Use tokens for API calls
    }

    override fun onFailure(error: CredentialsManagerException) {
        when (error.code) {
            "NO_CREDENTIALS" -> {
                // No credentials stored
            }
            "CREDENTIALS_EXPIRED" -> {
                // Credentials expired, user needs to login again
            }
            "REFRESH_FAILED" -> {
                // Refresh token expired, trigger re-authentication
            }
            else -> Log.e("CredentialsManager", error.message.orEmpty())
        }
    }
})

// Clear credentials (logout)
manager.clearCredentials()
```

**Key Features**:
- Credentials are encrypted at rest
- Automatic token refresh when credentials expire
- Handles refresh token expiration gracefully

## Biometric-Protected Credentials

Protect stored credentials with biometric authentication:

```kotlin
import com.auth0.android.authentication.AuthenticationAPIClient
import com.auth0.android.authentication.storage.SecureCredentialsManager
import com.auth0.android.authentication.storage.SharedPreferencesStorage
import com.auth0.android.authentication.storage.LocalAuthenticationOptions
import com.auth0.android.authentication.storage.AuthenticationLevel
import com.auth0.android.authentication.storage.BiometricPolicy
import androidx.fragment.app.FragmentActivity

val localAuthOptions = LocalAuthenticationOptions.Builder()
    .setTitle("Authenticate")
    .setDescription("Verify your fingerprint to access your account")
    .setAuthenticationLevel(AuthenticationLevel.STRONG)  // Fingerprint or face recognition
    .setNegativeButtonText("Cancel")
    .setDeviceCredentialFallback(true)  // Allow PIN/password fallback
    .setPolicy(BiometricPolicy.Session(300))  // Require biometric every 5 minutes
    .build()

val fragmentActivity: FragmentActivity = this  // Your Activity
val authentication = AuthenticationAPIClient(account)
val storage = SharedPreferencesStorage(context)
val manager = SecureCredentialsManager(
    context,
    authentication,
    storage,
    fragmentActivity,
    localAuthOptions
)

// Credentials are now biometric-protected
manager.saveCredentials(credentials)

// User must authenticate with biometric/device credential to retrieve
manager.getCredentials(callback)
```

**Authentication Levels**:
- `AuthenticationLevel.STRONG` — Biometric authentication required
- `AuthenticationLevel.WEAK` — Biometric or device credential (PIN/password)
- `AuthenticationLevel.DEVICE_CREDENTIAL` — PIN/password only

**Biometric Policies**:
- `BiometricPolicy.Never` — Never require biometric for retrieval
- `BiometricPolicy.Always` — Always require biometric
- `BiometricPolicy.Session(seconds)` — Require biometric every N seconds
- `BiometricPolicy.AppLifecycle` — Require biometric on app resume

## Database Login

Authenticate using username and password (requires `.validateClaims()`):

```kotlin
import com.auth0.android.authentication.AuthenticationAPIClient
import com.auth0.android.callback.Callback
import com.auth0.android.authentication.AuthenticationException
import com.auth0.android.result.Credentials

val authentication = AuthenticationAPIClient(account)

authentication.login(
    email = "user@example.com",
    password = "securePassword123",
    realm = "Username-Password-Authentication"
)
    .validateClaims()  // Critical: validate ID token claims
    .setScope("openid profile email offline_access")
    .start(object : Callback<Credentials, AuthenticationException> {
        override fun onSuccess(result: Credentials) {
            // User authenticated
            manager.saveCredentials(result)
        }

        override fun onFailure(error: AuthenticationException) {
            when {
                error.isMultifactorRequired -> {
                    // MFA required - see MFA Handling section
                }
                error.statusCode == 403 -> {
                    // Invalid credentials
                }
                else -> Log.e("Auth0", error.message.orEmpty())
            }
        }
    })
```

**Important**: Always call `.validateClaims()` when using `AuthenticationAPIClient` directly.

## Passwordless Authentication

Two-step passwordless flow using email codes:

### Step 1: Request Passwordless Code

```kotlin
import com.auth0.android.authentication.AuthenticationAPIClient
import com.auth0.android.authentication.PasswordlessType
import com.auth0.android.callback.Callback
import com.auth0.android.authentication.AuthenticationException

val authentication = AuthenticationAPIClient(account)

authentication.passwordlessWithEmail(
    email = "user@example.com",
    type = PasswordlessType.CODE
)
    .start(object : Callback<Void?, AuthenticationException> {
        override fun onSuccess(result: Void?) {
            // Code sent to email - show user a screen to enter code
        }

        override fun onFailure(error: AuthenticationException) {
            Log.e("Auth0", error.message.orEmpty())
        }
    })
```

### Step 2: Log In with Code

```kotlin
authentication.loginWithEmail(
    email = "user@example.com",
    code = "123456"  // Code from email
)
    .validateClaims()
    .start(object : Callback<Credentials, AuthenticationException> {
        override fun onSuccess(result: Credentials) {
            // User authenticated
            manager.saveCredentials(result)
        }

        override fun onFailure(error: AuthenticationException) {
            // Invalid or expired code
            Log.e("Auth0", error.message.orEmpty())
        }
    })
```

## Sign Up

Create a new account using the database connection:

```kotlin
val authentication = AuthenticationAPIClient(account)

authentication.signUp(
    email = "newuser@example.com",
    password = "securePassword123",
    username = "newuser",
    connection = "Username-Password-Authentication"
)
    .start(object : Callback<Void?, AuthenticationException> {
        override fun onSuccess(result: Void?) {
            // Account created successfully - user should now log in
        }

        override fun onFailure(error: AuthenticationException) {
            when {
                error.statusCode == 400 -> {
                    // User already exists or validation error
                }
                else -> Log.e("Auth0", error.message.orEmpty())
            }
        }
    })
```

After successful sign up, direct the user to log in using the database login flow.

## Calling Protected APIs

Attach the access token to your API requests:

```kotlin
import com.auth0.android.authentication.AuthenticationAPIClient
import com.auth0.android.authentication.storage.CredentialsManagerException
import com.auth0.android.authentication.storage.SecureCredentialsManager
import com.auth0.android.authentication.storage.SharedPreferencesStorage
import com.auth0.android.callback.Callback
import com.auth0.android.result.Credentials
import okhttp3.OkHttpClient
import okhttp3.Interceptor

val authentication = AuthenticationAPIClient(account)
val storage = SharedPreferencesStorage(context)
val manager = SecureCredentialsManager(context, authentication, storage)

manager.getCredentials(object : Callback<Credentials, CredentialsManagerException> {
    override fun onSuccess(result: Credentials) {
        val accessToken = result.accessToken

        // Use with OkHttp
        val httpClient = OkHttpClient.Builder()
            .addInterceptor(Interceptor { chain ->
                val request = chain.request().newBuilder()
                    .header("Authorization", "Bearer $accessToken")
                    .build()
                chain.proceed(request)
            })
            .build()

        // Or manually for other HTTP libraries
        val headers = mapOf("Authorization" to "Bearer $accessToken")
        // Use headers in your API request
    }

    override fun onFailure(error: CredentialsManagerException) {
        // Handle error - may need to re-authenticate
    }
})
```

If the API returns 401 Unauthorized, refresh the credentials and retry:

```kotlin
manager.getCredentials(object : Callback<Credentials, CredentialsManagerException> {
    override fun onSuccess(result: Credentials) {
        // Credentials were auto-refreshed by the manager
        val newAccessToken = result.accessToken
        retryApiCall(newAccessToken)
    }

    override fun onFailure(error: CredentialsManagerException) {
        if (error.code == "REFRESH_FAILED") {
            // Refresh token expired - trigger login again
        }
    }
})
```

## MFA Handling

Handle multi-factor authentication challenges:

### Detect MFA Required

```kotlin
authentication.login(...)
    .validateClaims()
    .start(object : Callback<Credentials, AuthenticationException> {
        override fun onFailure(error: AuthenticationException) {
            if (error.isMultifactorRequired) {
                val mfaToken = error.mfaRequiredErrorPayload?.mfaToken
                // Proceed to enrollment or challenge screen
            }
        }
    })
```

### Enroll in MFA

```kotlin
val mfaToken = error.mfaRequiredErrorPayload?.mfaToken ?: return
val mfaClient = authentication.mfaClient(mfaToken)

// Enroll in OTP
mfaClient.enroll(MfaEnrollmentType.Otp)
    .start(object : Callback<MfaEnrollment, AuthenticationException> {
        override fun onSuccess(enrollment: MfaEnrollment) {
            val recoveryCode = enrollment.recoveryCode
            val secret = enrollment.secret  // For OTP app
            // Show QR code to user
        }

        override fun onFailure(error: AuthenticationException) {
            Log.e("MFA", error.message.orEmpty())
        }
    })
```

### Challenge MFA

```kotlin
mfaClient.challenge(
    authenticatorId = "dev_abc123",  // From enrollments list
    challengeType = MfaChallengeType.OTP
)
    .start(object : Callback<MfaChallenge, AuthenticationException> {
        override fun onSuccess(challenge: MfaChallenge) {
            val challengeId = challenge.challengeId
            // Show user OTP input screen
        }

        override fun onFailure(error: AuthenticationException) {
            Log.e("MFA", error.message.orEmpty())
        }
    })
```

### Verify Challenge

```kotlin
mfaClient.verifyChallenge(
    challengeId = "Fe26...session_id",
    otp = "123456"  // User's one-time password
)
    .validateClaims()
    .start(object : Callback<Credentials, AuthenticationException> {
        override fun onSuccess(result: Credentials) {
            // MFA verified - user now authenticated
            manager.saveCredentials(result)
        }

        override fun onFailure(error: AuthenticationException) {
            // Invalid OTP or expired challenge
            Log.e("MFA", error.message.orEmpty())
        }
    })
```

## Organizations

Use Organizations for enterprise SSO and multi-tenancy:

```kotlin
// Log in with organization
WebAuthProvider.login(account)
    .withScheme(getString(R.string.com_auth0_scheme))
    .withOrganization("org_abc123")  // Organization ID
    .withScope("openid profile email")
    .start(this, object : Callback<Credentials, AuthenticationException> {
        override fun onSuccess(result: Credentials) {
            // User authenticated to organization
            val orgId = result.claims["org_id"]
        }

        override fun onFailure(error: AuthenticationException) {
            // Handle error
        }
    })

// Handle organization invitation link
val uri = intent.data  // From deep link
val organizationId = uri?.getQueryParameter("organization")
val invitation = uri?.getQueryParameter("invitation")

if (invitation != null) {
    WebAuthProvider.login(account)
        .withScheme(getString(R.string.com_auth0_scheme))
        .withInvitation(invitation)
        .start(this, callback)
}
```

## Error Handling

Handle authentication errors gracefully:

```kotlin
authentication.login(...)
    .start(object : Callback<Credentials, AuthenticationException> {
        override fun onFailure(error: AuthenticationException) {
            when {
                error.isMultifactorRequired -> {
                    // MFA enrollment or challenge required
                }
                error.isBrowserAppNotAvailable -> {
                    // No browser available
                    // Fallback to in-app WebView (not recommended)
                }
                error.isAuthenticationCanceled -> {
                    // User canceled the login flow
                }
                error.statusCode == 429 -> {
                    // Rate limited - too many login attempts
                }
                error.statusCode == 403 -> {
                    // Invalid credentials or user blocked
                }
                error.statusCode == 500 -> {
                    // Server error - retry later
                }
                else -> {
                    // Generic error
                    Log.e("Auth0", "Error: ${error.message}")
                }
            }
        }
    })
```

**CredentialsManagerException codes**:
- `NO_CREDENTIALS` — No credentials stored
- `CREDENTIALS_EXPIRED` — Stored credentials expired
- `REFRESH_FAILED` — Refresh token expired or invalid
- `INVALID_SECURITY` — Biometric authentication failed

## Custom Tabs

Customize the browser appearance:

```kotlin
import com.auth0.android.provider.CustomTabsOptions
import com.auth0.android.provider.WebAuthProvider

val customTabs = CustomTabsOptions.newBuilder()
    .withToolbarColor(R.color.toolbar_blue)
    .withShowTitle(true)
    .build()

WebAuthProvider.login(account)
    .withScheme(getString(R.string.com_auth0_scheme))
    .withCustomTabsOptions(customTabs)
    .start(this, callback)
```

**Options**:
- `.withToolbarColor()` — Toolbar color resource
- `.withShowTitle()` — Show the page title
- `.withStartAnimations()` — Entrance animation
- `.withExitAnimations()` — Exit animation

## Common Issues

| Issue | Solution |
|-------|----------|
| Deep link callback not working | Verify callback URL matches exactly: `https://{DOMAIN}/android/{PACKAGE}/callback`. Check manifest placeholders in `build.gradle`. |
| "Invalid state" error on callback | The auth session timed out or was invalidated. This can happen if the device went to sleep. Redirect user to login again. |
| Custom Tabs not opening | User may have disabled Custom Tabs. The SDK falls back to Chrome or system browser. If no browser available, `isBrowserAppNotAvailable` is true. |
| Biometric prompt not showing | Min SDK must be 21+ for biometric. Device must have fingerprint/face sensor registered. `setDeviceCredentialFallback(true)` allows PIN/password. |
| Token refresh fails | Refresh token may have expired (typically after 30 days). Trigger re-authentication with `WebAuthProvider.login()`. |
| ProGuard obfuscation breaks Auth0 | Auth0 rules are included automatically. If issues occur, add `-keep class com.auth0.** { *; }` to your `proguard-rules.pro`. |
