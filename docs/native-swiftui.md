# iOS SwiftUI interface

The iOS app now displays a native SwiftUI interface through `UiKitView`. Android and desktop keep the existing Flutter screens. The Flutter engine remains the single owner of authentication, API signing, devices, water sessions, and history reconciliation.

## Files

- `ios/Runner/WaterNativeViews.swift`: home, devices, login, bills, account, device management, and appearance screens.
- `ios/Runner/WaterNativeAppearance.swift`: independent wallpaper persistence, 18 solid presets, accent selection, glass controls, and native materials.
- `ios/Runner/WaterNativeBridge.swift`: platform-view lifecycle, Swift presentation store, and typed snapshots.
- `ios/Runner/WaterQRScanner.swift`: native AVFoundation QR scanner and permission handling.
- `lib/ui/pages/native_water_page.dart`: native action adapter to the existing Providers and API service.

## Behavior

- First row: account balance on the left, live duration on the right. Idle duration becomes today's total, with the previous duration below. With no records, it displays “随时用水”.
- Common devices remain in a two-column grid. Each retains rename, delete confirmation, default shortcut device, sorting, and monthly / lifetime statistics.
- A floating two-tab capsule switches water and device screens. Account remains a separate circular control. History and appearance are available from the top circular buttons.
- Selecting a card does not turn on the device. Start requires confirmation; stop calls the existing active order. Another selected card cannot redirect a stop.
- Login, bill month selection, cache clearing, profile information, and avatar picking / cropping retain their existing business behavior.
- Live Activities and App Intents retain their existing channels and native implementations. App resume still reconciles externally started / finished sessions.
- Wallpaper and appearance use independent native UserDefaults / Application Support storage. They survive account logout. The supplied screenshots' wallpaper is not embedded in the application; the user selects their own image.
- “莫奈配色” uses Flutter's actual Material ColorScheme image / seed algorithm, passing only generated color roles back to Swift. It does not read Android system wallpaper.
- On iOS 26+ with Xcode 26, cards use SwiftUI `glassEffect`; iOS 15–18 use an ultra-thin native material with a highlight rim. Reduce Transparency uses an opaque surface.

## Build and validation

The Runner minimum is iOS 15. The existing Live Activities extension retains its iOS 17 minimum. The unsigned workflow now uses macOS 15 and Xcode 26.0.1; `ios/Podfile` is included for its existing CocoaPods install step.

Local checks completed on Windows with Flutter 3.47.7 / Dart 3.13.5:

- Four Flutter tests pass, including native bridge snapshots, in-use device guards, active-device stop targeting, recovery / login guards, and the existing login render test.
- Dart analysis passes for the new bridge, main entry, and tests.
- Swift syntax parsing, Info.plist parsing, and Xcode source registration checks pass.

Windows has no Apple SDK or Xcode. SwiftUI type checking, iOS compilation, camera, real account APIs, system material rendering, avatar presentation, and Live Activities still require a Mac / iPhone validation pass. No real water device was operated during local tests.

On a Mac:

```sh
flutter pub get
cd ios && pod install && cd ..
flutter build ios --no-codesign
```

Then verify login, importing a wallpaper, changing the accent, adding / scanning a device, opening / closing water, month queries, avatar crop, and shortcut / Live Activity reconciliation on a test account and authorized device.

The HTML in `preview/liquid-glass` is a visual companion with simulated data. It approximates the native styling and must not be mistaken for an iOS runtime screenshot.
