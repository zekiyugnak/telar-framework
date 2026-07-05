---
id: blueprint-settings-screen
category: skill
impact: MEDIUM
impactDescription: Complete settings screen with sections, toggles, account management, and notification preferences
tags: [blueprint, settings, preferences, account, notifications, toggles]
capabilities:
  - Grouped settings with sections
  - Toggle switches with persistent state
  - Account management (edit profile, change password, delete account)
  - Notification preferences
  - Theme selection (light/dark/system)
useWhen:
  - Building a settings or preferences screen
  - Adding account management to an app
  - Need notification preference controls
  - Building a profile/settings flow
---

# Blueprint: Settings Screen

Settings screen with grouped sections, toggles, account management, notification preferences, and theme selection.

## File Manifest

```markdown
# React Native (TypeScript)
src/
  screens/settings/
    SettingsScreen.tsx
    AccountScreen.tsx
    NotificationPrefsScreen.tsx
  hooks/
    useSettings.ts
    useNotificationPrefs.ts
  components/settings/
    SettingsSection.tsx
    SettingsRow.tsx
    SettingsToggle.tsx
    DangerZone.tsx
  __tests__/
    useSettings.test.ts
    SettingsScreen.test.tsx

# Flutter (Dart)
lib/
  features/settings/
    screens/
      settings_screen.dart
      account_screen.dart
      notification_prefs_screen.dart
    providers/
      settings_provider.dart
      notification_prefs_provider.dart
    widgets/
      settings_section.dart
      settings_row.dart
      settings_toggle.dart
      danger_zone.dart
test/
  features/settings/
    settings_provider_test.dart
    settings_screen_test.dart
```

## React Native Implementation

### Settings Screen
```tsx
// src/screens/settings/SettingsScreen.tsx
import { ScrollView, Switch, Alert } from 'react-native';
import { useSettings } from '../../hooks/useSettings';
import { useAuth } from '../../hooks/useAuth';
import { SettingsSection } from '../../components/settings/SettingsSection';
import { SettingsRow } from '../../components/settings/SettingsRow';
import { SettingsToggle } from '../../components/settings/SettingsToggle';
import { DangerZone } from '../../components/settings/DangerZone';

export function SettingsScreen({ navigation }: Props) {
  const { settings, updateSetting } = useSettings();
  const { user, signOut } = useAuth();

  return (
    <ScrollView style={styles.container} accessibilityRole="list">
      <SettingsSection title="Account">
        <SettingsRow
          label="Profile"
          value={user?.email}
          onPress={() => navigation.navigate('Account')}
          accessibilityHint="Edit your profile information"
        />
        <SettingsRow
          label="Change Password"
          onPress={() => navigation.navigate('ChangePassword')}
          accessibilityHint="Change your account password"
        />
      </SettingsSection>

      <SettingsSection title="Appearance">
        <SettingsRow
          label="Theme"
          value={settings.theme === 'system' ? 'System' : settings.theme === 'dark' ? 'Dark' : 'Light'}
          onPress={() => navigation.navigate('ThemeSelection')}
          accessibilityHint="Choose light, dark, or system theme"
        />
      </SettingsSection>

      <SettingsSection title="Notifications">
        <SettingsToggle
          label="Push Notifications"
          value={settings.pushEnabled}
          onValueChange={(v) => updateSetting('pushEnabled', v)}
        />
        <SettingsToggle
          label="Email Notifications"
          value={settings.emailEnabled}
          onValueChange={(v) => updateSetting('emailEnabled', v)}
        />
        <SettingsRow
          label="Notification Preferences"
          onPress={() => navigation.navigate('NotificationPrefs')}
          accessibilityHint="Customize which notifications you receive"
        />
      </SettingsSection>

      <SettingsSection title="Privacy">
        <SettingsToggle
          label="Analytics"
          description="Help improve the app by sharing usage data"
          value={settings.analyticsEnabled}
          onValueChange={(v) => updateSetting('analyticsEnabled', v)}
        />
        <SettingsToggle
          label="Crash Reports"
          description="Automatically send crash reports"
          value={settings.crashReportsEnabled}
          onValueChange={(v) => updateSetting('crashReportsEnabled', v)}
        />
      </SettingsSection>

      <SettingsSection title="About">
        <SettingsRow label="Version" value="2.1.0" />
        <SettingsRow
          label="Terms of Service"
          onPress={() => Linking.openURL('https://example.com/terms')}
        />
        <SettingsRow
          label="Privacy Policy"
          onPress={() => Linking.openURL('https://example.com/privacy')}
        />
      </SettingsSection>

      <DangerZone>
        <SettingsRow
          label="Sign Out"
          destructive
          onPress={() => Alert.alert('Sign Out', 'Are you sure?', [
            { text: 'Cancel', style: 'cancel' },
            { text: 'Sign Out', style: 'destructive', onPress: signOut },
          ])}
        />
        <SettingsRow
          label="Delete Account"
          destructive
          onPress={() => navigation.navigate('DeleteAccount')}
          accessibilityHint="Permanently delete your account and data"
        />
      </DangerZone>
    </ScrollView>
  );
}
```

### Settings Hook
```typescript
// src/hooks/useSettings.ts
import { useCallback } from 'react';
import { useMMKVObject } from 'react-native-mmkv';

interface AppSettings {
  theme: 'light' | 'dark' | 'system';
  pushEnabled: boolean;
  emailEnabled: boolean;
  analyticsEnabled: boolean;
  crashReportsEnabled: boolean;
}

const defaults: AppSettings = {
  theme: 'system',
  pushEnabled: true,
  emailEnabled: true,
  analyticsEnabled: true,
  crashReportsEnabled: true,
};

export function useSettings() {
  const [settings = defaults, setSettings] = useMMKVObject<AppSettings>('app_settings');

  const updateSetting = useCallback(<K extends keyof AppSettings>(
    key: K,
    value: AppSettings[K],
  ) => {
    setSettings(prev => ({ ...(prev ?? defaults), [key]: value }));
  }, [setSettings]);

  return { settings, updateSetting };
}
```

## Flutter Implementation

### Settings Screen
```dart
// lib/features/settings/screens/settings_screen.dart
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final auth = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SettingsSection(
            title: 'Account',
            children: [
              SettingsRow(
                label: 'Profile',
                value: auth.user?.email,
                onTap: () => context.push('/settings/account'),
              ),
              SettingsRow(
                label: 'Change Password',
                onTap: () => context.push('/settings/change-password'),
              ),
            ],
          ),
          SettingsSection(
            title: 'Appearance',
            children: [
              SettingsRow(
                label: 'Theme',
                value: settings.theme.displayName,
                onTap: () => _showThemePicker(context, ref),
              ),
            ],
          ),
          SettingsSection(
            title: 'Notifications',
            children: [
              SettingsToggle(
                label: 'Push Notifications',
                value: settings.pushEnabled,
                onChanged: (v) => ref.read(settingsProvider.notifier).update(pushEnabled: v),
              ),
              SettingsToggle(
                label: 'Email Notifications',
                value: settings.emailEnabled,
                onChanged: (v) => ref.read(settingsProvider.notifier).update(emailEnabled: v),
              ),
              SettingsRow(
                label: 'Notification Preferences',
                onTap: () => context.push('/settings/notifications'),
              ),
            ],
          ),
          SettingsSection(
            title: 'Privacy',
            children: [
              SettingsToggle(
                label: 'Analytics',
                subtitle: 'Help improve the app by sharing usage data',
                value: settings.analyticsEnabled,
                onChanged: (v) => ref.read(settingsProvider.notifier).update(analyticsEnabled: v),
              ),
            ],
          ),
          SettingsSection(
            title: 'About',
            children: [
              const SettingsRow(label: 'Version', value: '2.1.0'),
              SettingsRow(
                label: 'Terms of Service',
                onTap: () => launchUrl(Uri.parse('https://example.com/terms')),
              ),
              SettingsRow(
                label: 'Privacy Policy',
                onTap: () => launchUrl(Uri.parse('https://example.com/privacy')),
              ),
            ],
          ),
          DangerZone(
            children: [
              SettingsRow(
                label: 'Sign Out',
                destructive: true,
                onTap: () => _confirmSignOut(context, ref),
              ),
              SettingsRow(
                label: 'Delete Account',
                destructive: true,
                onTap: () => context.push('/settings/delete-account'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

## Supabase Backend

```sql
-- User settings stored server-side for cross-device sync
CREATE TABLE public.user_settings (
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  push_enabled BOOLEAN DEFAULT true,
  email_enabled BOOLEAN DEFAULT true,
  analytics_enabled BOOLEAN DEFAULT true,
  theme TEXT DEFAULT 'system' CHECK (theme IN ('light', 'dark', 'system')),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own settings"
  ON public.user_settings FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
```

## Tests

```typescript
describe('useSettings', () => {
  it('returns default settings', () => {
    const { result } = renderHook(() => useSettings());
    expect(result.current.settings.theme).toBe('system');
    expect(result.current.settings.pushEnabled).toBe(true);
  });

  it('persists setting changes', () => {
    const { result } = renderHook(() => useSettings());
    act(() => { result.current.updateSetting('theme', 'dark'); });
    expect(result.current.settings.theme).toBe('dark');
  });
});
```

## Accessibility Checklist

- [x] All toggles have accessible labels and state descriptions
- [x] Section headers use appropriate heading roles
- [x] Destructive actions have confirmation dialogs
- [x] Links to external content indicated with hints
- [x] Toggle descriptions read as part of the toggle's accessible label
- [x] Delete account has multi-step confirmation
