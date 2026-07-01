## Testing

### iOS Testing

1. Run the app: `npx react-native run-ios` or `npx expo run:ios`
2. Tap "Login" button
3. Safari opens with Auth0 Universal Login
4. Complete authentication
5. App opens via deep link with user authenticated
6. Tap "Logout" and verify session cleared

### Android Testing

1. Run the app: `npx react-native run-android` or `npx expo run:android`
2. Tap "Login" button
3. Chrome Custom Tabs opens with Auth0 login
4. Complete authentication
5. App resumes via intent filter with user authenticated
6. Tap "Logout" and verify session cleared

---

## Common Issues

| Issue | Solution |
|-------|----------|
| Deep link not working (iOS) | Check `CFBundleURLSchemes` matches bundle identifier exactly |
| Deep link not working (Android) | Verify `android:scheme` and `android:host` in AndroidManifest.xml |
| "Invalid state" error | Clear app data and reinstall. Check callback URLs match configuration |
| Login opens but doesn't return to app | Ensure deep linking is properly configured and tested |
| Expo build fails | Run `npx expo prebuild` to generate native configuration |
| iOS builds fail after pod install | Run `cd ios && pod deintegrate && pod install` |

---

## Security Considerations

- **Use secure storage** - Credentials are stored securely using Keychain (iOS) and Keystore (Android)
- **HTTPS only** - Auth0 requires HTTPS callback URLs (except localhost for dev)
- **Validate tokens on backend** - Never trust client-side token validation
- **Use PKCE** - Enabled by default with react-native-auth0
- **Implement biometric authentication** - Use react-native-biometrics with Auth0 for enhanced security
- **Handle token expiration** - Implement refresh token logic with `getCredentials()`

---

## Related Skills

- `auth0-quickstart` - Initial Auth0 account setup
- `auth0-migration` - Migrate from another auth provider
- `auth0-mfa` - Add Multi-Factor Authentication
- `auth0-passkeys` - Add passkey authentication
- `auth0-organizations` - B2B multi-tenancy support

---

## References

- [React Native Auth0 SDK Documentation](https://auth0.com/docs/libraries/auth0-react-native)
- [React Native Auth0 SDK GitHub](https://github.com/auth0/react-native-auth0)
- [Auth0 React Native Quickstart](https://auth0.com/docs/quickstart/native/react-native)
- [React Native Deep Linking](https://reactnative.dev/docs/linking)
- [Expo Deep Linking](https://docs.expo.dev/guides/deep-linking/)
