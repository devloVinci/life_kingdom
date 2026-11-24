# Notifications

## How it works
`NotificationPlanner` (pure Dart, tested) turns the game state into concrete
one-shot notifications for the next 14 days:

| Kind | When | Skipped if |
|---|---|---|
| Habit reminder | the habit's reminder time, on its due weekdays | already done today |
| Unfinished habits | 20:00 daily | nothing is left today |
| Open the app | 18:00, from tomorrow on | toggle off |

The schedule is rebuilt every time the app opens and on every state change
(identical plans are not re-sent). Max 60 pending (iOS limit is 64).
Toggles live in Settings; each kind can be switched off.

Not yet scheduled: level-up / achievement notifications. They happen while the
app is open, where the in-app celebration already shows them.

## One-time native setup (Android)
Run `flutter create . --project-name life_kingdom --platforms=web,android`, then:

1. `android/app/src/main/AndroidManifest.xml`, inside `<manifest>`:
   ```xml
   <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
   <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
   ```
   and inside `<application>`:
   ```xml
   <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
     <intent-filter>
       <action android:name="android.intent.action.BOOT_COMPLETED"/>
       <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
       <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
       <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
     </intent-filter>
   </receiver>
   <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
   ```
2. `android/app/build.gradle(.kts)`: enable core library desugaring
   (`isCoreLibraryDesugaringEnabled = true` in `compileOptions`, and
   `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")` in dependencies).
3. Reminders use inexact alarms (can be a few minutes late) so no special
   "exact alarm" permission is needed.

Then open Settings > Notifications > "Allow notifications" and "Send a test".

## Web / iPhone
- Browser: scheduled notifications cannot fire while the app is closed. The
  toggles are saved, nothing is delivered.
- iPhone: a PWA can only get push notifications from a server (Web Push), and
  only on iOS 16.4+ after "Add to Home Screen". That needs a small backend
  (e.g. Firebase Cloud Messaging + a scheduled function) and is a separate step.
  A native iOS build (Xcode / Mac) would use the same code as Android.
