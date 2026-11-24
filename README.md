# Life Kingdom

Gamified habit and self-development app (Clash-style kingdom RPG), built with Flutter.

## Setup
```
flutter create . --project-name life_kingdom --platforms=web,android
flutter pub get
flutter run -d chrome
```
`flutter create .` only adds the platform folders; it keeps the existing `lib/` and `pubspec.yaml`.

## Structure
- `lib/core/theme` - colors, text styles, theme
- `lib/core/widgets` - shared game widgets (button, panel, counters, rarity frame, rank badge, XP bar)
- `lib/features/*` - one folder per feature/screen
- `assets/characters/` - exported character SVG parts

## Notifications (Android / iPhone)
Scheduled with `flutter_local_notifications`; see `docs/notifications.md` for the
one-time native setup after `flutter create`.
