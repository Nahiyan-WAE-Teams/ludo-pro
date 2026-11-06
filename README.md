# Ludo Pro · Native Android

**This is the native Godot rebuild.** The earlier HTML/JavaScript browser prototype is not the Android product.

## Technology
- Godot 4.4 and GDScript 2.0
- Native 2D drawing, touch input, frame-based animation and local persistence
- No WebView, browser, HTML/CSS/JavaScript runtime, backend, API or network dependency

## Open and run
Open this repository folder in Godot 4.4 and press Run. The project is configured for landscape orientation.

Run the rules checks:
```sh
godot --headless --path . --script res://tests/test_rules.gd
```

## Current native gameplay foundation
- Four player colors and four tokens per player
- Solo vs three AI, two local players plus two AI, or four local players (mode selector UI is the next polish pass)
- Six to release, outer track, colored home lanes, safe squares, captures, exact home entry, bonus turns and three-six forfeiture
- Balanced, tactical and champion AI scoring
- Native token movement animation and touch selection
- Local match persistence in user://ludo_pro_save.cfg

## Android APK
Install Godot 4.4 export templates and configure Android SDK/JDK in Editor Settings. Create an Android export preset and export a debug APK. A signed release requires a user-owned keystore. The source project is not represented as a tested APK until export and device verification succeed.
