# Multi-Environment Configuration Guide

Set up development, staging, and production environments for mobile apps.

## React Native (Expo)

### Using app.config.ts

```typescript
// app.config.ts
import { ExpoConfig, ConfigContext } from 'expo/config'

const IS_DEV = process.env.APP_VARIANT === 'development'
const IS_STAGING = process.env.APP_VARIANT === 'staging'

const getAppName = () => {
  if (IS_DEV) return 'MyApp (Dev)'
  if (IS_STAGING) return 'MyApp (Staging)'
  return 'MyApp'
}

const getBundleId = () => {
  if (IS_DEV) return 'com.company.myapp.dev'
  if (IS_STAGING) return 'com.company.myapp.staging'
  return 'com.company.myapp'
}

export default ({ config }: ConfigContext): ExpoConfig => ({
  ...config,
  name: getAppName(),
  slug: 'myapp',
  ios: {
    bundleIdentifier: getBundleId(),
  },
  android: {
    package: getBundleId(),
  },
  extra: {
    apiUrl: IS_DEV
      ? 'http://localhost:3000'
      : IS_STAGING
        ? 'https://staging-api.company.com'
        : 'https://api.company.com',
    supabaseUrl: IS_DEV
      ? 'http://localhost:54321'
      : IS_STAGING
        ? 'https://staging.supabase.co'
        : 'https://prod.supabase.co',
  },
})
```

### eas.json Build Profiles

```json
{
  "build": {
    "development": {
      "developmentClient": true,
      "distribution": "internal",
      "env": {
        "APP_VARIANT": "development"
      }
    },
    "staging": {
      "distribution": "internal",
      "env": {
        "APP_VARIANT": "staging"
      },
      "channel": "staging"
    },
    "production": {
      "env": {
        "APP_VARIANT": "production"
      },
      "channel": "production",
      "autoIncrement": true
    }
  }
}
```

### Access Config Values

```typescript
import Constants from 'expo-constants'

const config = Constants.expoConfig?.extra
const API_URL = config?.apiUrl
const SUPABASE_URL = config?.supabaseUrl
```

## React Native (Bare - react-native-config)

### Setup

```bash
npm install react-native-config
```

### Environment Files

```bash
# .env.development
API_URL=http://localhost:3000
SUPABASE_URL=http://localhost:54321
SUPABASE_ANON_KEY=eyJ...dev

# .env.staging
API_URL=https://staging-api.company.com
SUPABASE_URL=https://staging.supabase.co
SUPABASE_ANON_KEY=eyJ...staging

# .env.production
API_URL=https://api.company.com
SUPABASE_URL=https://prod.supabase.co
SUPABASE_ANON_KEY=eyJ...prod
```

### Usage

```typescript
import Config from 'react-native-config'

const API_URL = Config.API_URL
const SUPABASE_URL = Config.SUPABASE_URL
```

### Build with Specific Env

```bash
# Android
ENVFILE=.env.staging npx react-native run-android

# iOS
ENVFILE=.env.staging npx react-native run-ios
```

## Flutter

### Using --dart-define

```bash
# Run with environment
flutter run --dart-define=ENV=development
flutter run --dart-define=ENV=staging
flutter build apk --dart-define=ENV=production
```

### Environment Config Class

```dart
// lib/config/environment.dart
enum Environment { development, staging, production }

class EnvConfig {
  final Environment environment;
  final String apiUrl;
  final String supabaseUrl;
  final String supabaseAnonKey;

  const EnvConfig._({
    required this.environment,
    required this.apiUrl,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  static EnvConfig? _instance;
  static EnvConfig get instance => _instance!;

  static void initialize(Environment env) {
    _instance = switch (env) {
      Environment.development => const EnvConfig._(
        environment: Environment.development,
        apiUrl: 'http://localhost:3000',
        supabaseUrl: 'http://localhost:54321',
        supabaseAnonKey: 'eyJ...dev',
      ),
      Environment.staging => const EnvConfig._(
        environment: Environment.staging,
        apiUrl: 'https://staging-api.company.com',
        supabaseUrl: 'https://staging.supabase.co',
        supabaseAnonKey: 'eyJ...staging',
      ),
      Environment.production => const EnvConfig._(
        environment: Environment.production,
        apiUrl: 'https://api.company.com',
        supabaseUrl: 'https://prod.supabase.co',
        supabaseAnonKey: 'eyJ...prod',
      ),
    };
  }
}
```

### Entry Points per Environment

```dart
// lib/main_dev.dart
import 'config/environment.dart';
import 'main_common.dart';

void main() {
  EnvConfig.initialize(Environment.development);
  mainCommon();
}

// lib/main_staging.dart
import 'config/environment.dart';
import 'main_common.dart';

void main() {
  EnvConfig.initialize(Environment.staging);
  mainCommon();
}

// lib/main.dart (production)
import 'config/environment.dart';
import 'main_common.dart';

void main() {
  EnvConfig.initialize(Environment.production);
  mainCommon();
}
```

### Run Specific Environment

```bash
flutter run -t lib/main_dev.dart
flutter run -t lib/main_staging.dart
flutter build apk -t lib/main.dart
```

## Security Rules

1. **Never commit** `.env` files with real secrets to git
2. **Add to .gitignore**: `.env`, `.env.*`, `!.env.example`
3. **Create `.env.example`** with placeholder values for documentation
4. **CI/CD secrets** stored in GitHub Secrets, Expo Secrets, or similar
5. **Publishable keys only** in client code (Supabase anon key, Stripe publishable key)
6. **Never** put service role keys, API secrets, or private keys in client code
