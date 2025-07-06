# Secure Lifetime Usage Tracking System

## Overview

The Igbo Bible App now implements a secure lifetime usage tracking system that prevents users from easily circumventing usage limits by clearing app data. The system provides different levels of security based on user authentication status.

## Features

### 🔐 Secure Lifetime Limits

- **Translations**: 3 total for free users (lifetime)
- **Image Generation**: 5 total for free users (lifetime)
- **Permanent Limits**: Once exceeded, users must subscribe for unlimited access
- **No Daily Reset**: Limits are permanent until subscription

### 🛡️ Security Levels

#### For Authenticated Users (Firebase)

- Usage data stored securely in Firebase Firestore
- Data tied to user account and cannot be cleared by clearing app data
- Automatic cleanup of old usage data (older than 30 days)
- Real-time synchronization across devices

#### For Anonymous Users (Local Storage)

- Enhanced local storage with date-based keys
- Automatic daily reset detection
- Fallback mechanism if Firebase is unavailable

## Implementation Details

### UsageService Class

The `UsageService` class provides the following key methods:

```dart
// Check if user can use translation feature
Future<bool> canUseTranslation()

// Check if user can use image generation feature
Future<bool> canUseImage()

// Increment usage counters
Future<void> incrementTranslation()
Future<void> incrementImage()

// Get current usage statistics
Future<Map<String, int>> getUsageStats()

// Check subscription status
Future<bool> isSubscribed()

// Reset daily usage (admin function)
Future<void> resetDailyUsage()
```

### Data Storage Structure

#### Firebase (Authenticated Users)

```
users/{userId}/usage/{date}
{
  "translations": 2,
  "images": 1,
  "date": "2024-01-15",
  "lastUpdated": timestamp
}
```

#### Local Storage (Anonymous Users)

```
translations_used_2024-01-15: 2
images_used_2024-01-15: 1
last_reset_date: "2024-01-15"
```

### Daily Reset Logic

1. **Date Detection**: System checks if current date differs from last reset date
2. **Automatic Reset**: If date has changed, usage counters are automatically reset
3. **Cross-Device Sync**: For authenticated users, reset is synchronized across devices

## Usage in App

### Translation Screen

```dart
final usageService = UsageService();
if (!await usageService.canUseTranslation()) {
  _showError('Translation limit reached. Subscribe for unlimited access.');
  return;
}
await usageService.incrementTranslation();
// Proceed with translation
```

### Image Generation

```dart
final usageService = UsageService();
if (!await usageService.canUseImage()) {
  _showError('Image generation limit reached. Subscribe for unlimited access.');
  return;
}
await usageService.incrementImage();
// Proceed with image generation
```

### Settings Screen

The settings screen now displays:

- Current daily usage for translations and images
- Visual indicators for limit status
- Subscription status
- Progress bars showing usage vs limits

## Security Benefits

1. **Prevents Data Clearing**: Authenticated users cannot bypass limits by clearing app data
2. **Cross-Device Enforcement**: Limits apply across all user devices
3. **Server-Side Validation**: Usage data stored securely in Firebase
4. **Automatic Cleanup**: Old usage data automatically removed after 30 days
5. **Fallback Protection**: Local storage provides backup when Firebase is unavailable

## Testing

Run the usage service tests:

```bash
flutter test test/usage_service_test.dart
```

The tests verify:

- Daily limit enforcement
- Usage increment functionality
- Reset functionality
- Cross-day persistence
- Subscription bypass logic

## Migration from Old System

The new system is backward compatible. Existing users will:

1. Start with fresh daily limits on first app launch
2. Maintain subscription status if previously subscribed
3. See their usage tracked from the new system forward

## Configuration

Usage limits can be adjusted by modifying constants in `UsageService`:

```dart
static const int translationLimit = 3;
static const int imageLimit = 5;
```

## Monitoring

Usage data can be monitored in Firebase Console:

- Navigate to Firestore Database
- View `users/{userId}/usage` collection
- Monitor daily usage patterns and subscription status
