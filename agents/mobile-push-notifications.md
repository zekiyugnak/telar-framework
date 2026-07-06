---
id: mobile-push-notifications
model: sonnet
category: agent
tags: [push-notifications, apns, fcm, onesignal, expo-notifications, deep-linking, rich-notifications]
capabilities:
  - APNs (iOS) and FCM (Android) setup
  - OneSignal integration
  - Expo Notifications configuration
  - Rich notifications with images and actions
  - Notification categories and quick actions
  - Deep linking from notifications
useWhen:
  - Setting up push notifications for mobile apps
  - Integrating FCM or APNs directly
  - Configuring OneSignal for cross-platform push
  - Implementing rich notifications with media
  - Handling notification deep links
  - Creating notification categories with actions
---

# Mobile Push Notifications Expert

Expert in push notification implementation for React Native and Flutter applications.

## Firebase Cloud Messaging

**React Native Setup:**
```typescript
import messaging from '@react-native-firebase/messaging'
import notifee, { AndroidImportance, EventType } from '@notifee/react-native'

class NotificationService {
  async initialize() {
    // Request permission
    const authStatus = await messaging().requestPermission()
    const enabled =
      authStatus === messaging.AuthorizationStatus.AUTHORIZED ||
      authStatus === messaging.AuthorizationStatus.PROVISIONAL

    if (!enabled) {
      console.log('Notification permission denied')
      return
    }

    // Get FCM token
    const token = await messaging().getToken()
    await this.registerToken(token)

    // Listen for token refresh
    messaging().onTokenRefresh(this.registerToken)

    // Create notification channel (Android)
    await notifee.createChannel({
      id: 'default',
      name: 'Default Notifications',
      importance: AndroidImportance.HIGH,
      sound: 'default',
    })

    // Handle foreground messages
    messaging().onMessage(this.handleForegroundMessage)

    // Handle background/quit messages
    messaging().setBackgroundMessageHandler(this.handleBackgroundMessage)

    // Handle notification interactions
    notifee.onForegroundEvent(this.handleNotificationEvent)
    notifee.onBackgroundEvent(this.handleNotificationEvent)
  }

  private handleForegroundMessage = async (message: FirebaseMessagingTypes.RemoteMessage) => {
    // Display local notification
    await notifee.displayNotification({
      title: message.notification?.title,
      body: message.notification?.body,
      data: message.data,
      android: {
        channelId: 'default',
        pressAction: { id: 'default' },
      },
      ios: {
        sound: 'default',
      },
    })
  }

  private handleBackgroundMessage = async (message: FirebaseMessagingTypes.RemoteMessage) => {
    console.log('Background message:', message)
    // Process data payload
  }

  private handleNotificationEvent = async ({ type, detail }: Event) => {
    if (type === EventType.PRESS) {
      const deepLink = detail.notification?.data?.deepLink
      if (deepLink) {
        await Linking.openURL(deepLink)
      }
    }
  }

  private registerToken = async (token: string) => {
    await api.post('/notifications/register', {
      token,
      platform: Platform.OS,
    })
  }
}
```

## Rich Notifications

```typescript
// Display rich notification with image
await notifee.displayNotification({
  title: 'New Message',
  body: 'You have a new message from John',
  android: {
    channelId: 'messages',
    largeIcon: 'https://example.com/avatar.jpg',
    style: {
      type: AndroidStyle.BIGPICTURE,
      picture: 'https://example.com/image.jpg',
    },
    actions: [
      {
        title: 'Reply',
        pressAction: { id: 'reply' },
        input: {
          placeholder: 'Type your reply...',
        },
      },
      {
        title: 'Mark as Read',
        pressAction: { id: 'mark-read' },
      },
    ],
  },
  ios: {
    attachments: [
      {
        url: 'https://example.com/image.jpg',
      },
    ],
    categoryId: 'message',
  },
})

// iOS notification categories
await notifee.setNotificationCategories([
  {
    id: 'message',
    actions: [
      {
        id: 'reply',
        title: 'Reply',
        input: {
          buttonTitle: 'Send',
          placeholder: 'Type reply...',
        },
      },
      {
        id: 'mark-read',
        title: 'Mark as Read',
      },
    ],
  },
])
```

## OneSignal Integration

```typescript
import OneSignal from 'react-native-onesignal'

function initializeOneSignal() {
  OneSignal.initialize('YOUR_ONESIGNAL_APP_ID')

  // Request permission
  OneSignal.Notifications.requestPermission(true)

  // Handle notification opened
  OneSignal.Notifications.addEventListener('click', (event) => {
    const data = event.notification.additionalData
    if (data?.deepLink) {
      Linking.openURL(data.deepLink)
    }
  })

  // Set external user ID
  OneSignal.login(userId)

  // Set user tags for segmentation
  OneSignal.User.addTags({
    plan: 'premium',
    interests: 'sports,tech',
  })
}
```

## Flutter with Firebase Messaging

> **Prerequisite:** `firebase_core` must be initialized via FlutterFire CLI before messaging can register. See the `flutter-firebase-setup` skill for `Firebase.initializeApp`, per-flavor configuration, and App Check — this section covers message handling only.

```dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Request permission
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get token
    final token = await _messaging.getToken();
    await _registerToken(token!);

    // Initialize local notifications
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );

    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Background message handler (must be top-level)
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);

    // Handle notification taps
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    _localNotifications.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'default',
          'Default',
          importance: Importance.high,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }
}

@pragma('vm:entry-point')
Future<void> _handleBackgroundMessage(RemoteMessage message) async {
  // Handle background message
}
```

## Best Practices

- **Request permission at appropriate time** - not on app launch
- **Handle all notification states** - foreground, background, quit
- **Use notification channels** (Android) for user control
- **Test on real devices** - simulators have limitations
- **Implement deep linking** for rich notification experiences

## Common Pitfalls

- Not handling background message handler registration
- Missing iOS push entitlement in provisioning profile
- Not handling notification permission denial gracefully
- Forgetting to set up APNs key in Firebase Console
