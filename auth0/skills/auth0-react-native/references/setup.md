# Auth0 React Native Setup Guide

Setup instructions for React Native and Expo mobile applications.

---

## Quick Setup

### For Expo

```bash
# Install SDK
npx expo install react-native-auth0

# Configure app.json
# Add scheme, bundleIdentifier, and package
```

### For React Native CLI

```bash
# Install SDK
npm install react-native-auth0

# iOS: Install pods
cd ios && pod install && cd ..

# Configure iOS Info.plist and Android AndroidManifest.xml
```

---

## Manual Setup

### 1. Install SDK

**Expo:**
```bash
npx expo install react-native-auth0
```

**React Native CLI:**
```bash
npm install react-native-auth0
npx pod-install  # iOS only
```

### 2. Create Auth0 Native Application

Via CLI:
```bash
auth0 login
auth0 apps create --name "My Mobile App" --type native \
  --auth-method None \
  --callbacks "com.yourcompany.yourapp.auth0://YOUR_DOMAIN/ios/com.yourcompany.yourapp/callback,com.yourcompany.yourapp.auth0://YOUR_DOMAIN/android/com.yourcompany.yourapp/callback" \
  --logout-urls "com.yourcompany.yourapp.auth0://YOUR_DOMAIN/ios/com.yourcompany.yourapp/callback,com.yourcompany.yourapp.auth0://YOUR_DOMAIN/android/com.yourcompany.yourapp/callback" \
  --metadata "created_by=agent_skills"
```

Via Dashboard:
1. Create **Native** application type
2. Configure callback URLs with your app scheme
3. Copy domain and client ID

### 3. Configure iOS

Update `ios/{YourApp}/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>None</string>
    <key>CFBundleURLName</key>
    <string>auth0</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>$(PRODUCT_BUNDLE_IDENTIFIER).auth0</string>
    </array>
  </dict>
</array>
```

### 4. Configure Android

Update `android/app/src/main/AndroidManifest.xml`:

```xml
<activity android:name="com.auth0.android.provider.RedirectActivity" android:exported="true">
  <intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data
      android:host="YOUR_DOMAIN"
      android:pathPrefix="/android/${applicationId}/callback"
      android:scheme="${applicationId}" />
  </intent-filter>
</activity>
```

### 5. Configure Expo

Update `app.json`:

```json
{
  "expo": {
    "scheme": "myappscheme",
    "ios": {
      "bundleIdentifier": "com.mycompany.myapp"
    },
    "android": {
      "package": "com.mycompany.myapp"
    }
  }
}
```

---

## Troubleshooting

**Callback not working:**
- Verify scheme matches bundle ID/package name
- Check Auth0 allowed callbacks include your scheme

**Build errors on iOS:**
- Run `pod install` in ios/ directory
- Clean build folder in Xcode

**Android redirect issues:**
- Ensure RedirectActivity is exported
- Check scheme matches package name

---

## Next Steps

- [Patterns Guide](patterns.md) - Implementation patterns
- [API Reference](api.md) - Complete SDK API
- [Main Skill](../SKILL.md) - Quick start workflow
