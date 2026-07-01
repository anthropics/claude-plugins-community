## Common Patterns

### Protected Screen with Navigation

```tsx
import { useAuth0 } from 'react-native-auth0';
import { useEffect } from 'react';
import { NavigationProp } from '@react-navigation/native';

export function ProtectedScreen({ navigation }: { navigation: NavigationProp<any> }) {
  const { user, isLoading } = useAuth0();

  useEffect(() => {
    if (!isLoading && !user) {
      navigation.navigate('Login');
    }
  }, [isLoading, user, navigation]);

  if (isLoading) {
    return <ActivityIndicator />;
  }

  if (!user) {
    return null;
  }

  return (
    <View>
      <Text>Protected Content</Text>
      <Text>User ID: {user.sub}</Text>
    </View>
  );
}
```

---

### Get User Profile

```tsx
import { useAuth0 } from 'react-native-auth0';
import { View, Text, Image } from 'react-native';

export function ProfileScreen() {
  const { user } = useAuth0();

  if (!user) {
    return <Text>Please log in</Text>;
  }

  return (
    <View>
      {user.picture && (
        <Image
          source={{ uri: user.picture }}
          style={{ width: 100, height: 100, borderRadius: 50 }}
        />
      )}
      <Text>Name: {user.name}</Text>
      <Text>Email: {user.email}</Text>
      <Text>Email Verified: {user.email_verified ? 'Yes' : 'No'}</Text>
      <Text>User ID: {user.sub}</Text>
    </View>
  );
}
```

---

### Call Protected API

```tsx
import { useAuth0 } from 'react-native-auth0';
import { useState } from 'react';
import { View, Button, Text } from 'react-native';

export function ApiTestScreen() {
  const { getCredentials } = useAuth0();
  const [data, setData] = useState(null);
  const [error, setError] = useState(null);

  const callApi = async () => {
    try {
      const credentials = await getCredentials();

      const response = await fetch('https://your-api.com/data', {
        headers: {
          Authorization: `Bearer ${credentials.accessToken}`
        }
      });

      const json = await response.json();
      setData(json);
    } catch (err) {
      setError(err.message);
    }
  };

  return (
    <View>
      <Button title="Call API" onPress={callApi} />
      {error && <Text>Error: {error}</Text>}
      {data && <Text>{JSON.stringify(data, null, 2)}</Text>}
    </View>
  );
}
```

**Note:** To call APIs, configure `audience` parameter:

```tsx
const login = async () => {
  await authorize({
    audience: 'https://your-api-identifier',
    scope: 'openid profile email'
  });
};
```

---

### Silent Authentication

```tsx
import { useAuth0 } from 'react-native-auth0';
import { useEffect } from 'react';

export function App() {
  const { getCredentials, user } = useAuth0();

  useEffect(() => {
    // Attempt silent authentication on app start
    const checkAuth = async () => {
      try {
        await getCredentials();
      } catch (e) {
        // User not logged in, do nothing
      }
    };

    if (!user) {
      checkAuth();
    }
  }, []);

  // Rest of your app...
}
```

---

### Custom Login Options

```tsx
const login = async () => {
  await authorize({
    scope: 'openid profile email offline_access',
    audience: 'https://your-api-identifier',
    connection: 'google-oauth2', // Optional: force specific connection
    prompt: 'login', // Force re-authentication
  });
};
```

---

## Configuration Options

### Complete Auth0Provider Configuration

```tsx
<Auth0Provider
  domain="your-tenant.auth0.com"
  clientId="your-client-id"
>
  <App />
</Auth0Provider>
```

### Complete authorize() Options

```tsx
await authorize({
  scope: 'openid profile email offline_access',
  audience: 'https://your-api-identifier',
  connection: 'Username-Password-Authentication', // Optional
  prompt: 'login', // or 'consent'
  screen_hint: 'signup', // Show signup instead of login
  max_age: 300, // Force re-auth if session older than 5 minutes
});
```

---
