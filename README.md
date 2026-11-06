# Ludo Pro · Native Android

**Ludo Pro is a native Godot 4.4 game.** It is not a browser game or a WebView wrapper.

## Visual direction
- Midnight-blue game shell with restrained warm-gold accents
- Ivory board surface, four distinct player houses and high-contrast token states
- Larger, readable status hierarchy and touch-friendly controls
- Responsive canvas scaling for landscape Android displays
- Animated dice roll, eased token movement with a hop, capture/home particle bursts and contextual action banners

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

## Adaptive AI

The three AI levels use a shared board evaluator with different risk tolerance:

- **Balanced:** considers a wider set of close-scoring moves and varies its decisions.
- **Tactical:** narrows choices to stronger moves and values safe squares, progress, captures and exposure.
- **Champion:** evaluates the resulting board, checks opponent capture windows, prioritizes dangerous leaders, and searches the expected value of bonus turns across all six possible next dice rolls.

The evaluator accounts for exact track distance to enemy tokens, safe-square immunity, home-lane progress, token exposure, capture value, home completion and useful token formations. It is deterministic at Champion difficulty, so the strongest move is selected consistently for a given board and roll.

### Champion opponent-turn search

Champion mode now runs a three-opponent expectimax search after each candidate move. It models each of the next three opponents receiving a fair six-sided die roll, then choosing their strongest response. The AI averages those chance outcomes, values captures against leading opponents, and subtracts the resulting danger from its candidate move score. This is deeper than a static six-square threat check, while remaining bounded to three opponent turns so it stays practical on mobile hardware.

### Victory announcement

When a match is won, the game launches a full-screen animated congratulations ceremony, fireworks particles, a champion callout, and a short vibration. On Android devices with an installed native text-to-speech voice, it also speaks the winner's name and announces: "Congratulations, Ruby! You are the Ludo Pro champion!" The spoken name changes with the winning color. If device speech is unavailable, the visual announcement still plays.

## Gameplay
- Four player colors and four tokens per player
- Solo vs three AI, two local players plus two AI, or four local players
- Six to release, 52-square outer track, colored home lanes, safe squares, captures, exact home entry, bonus turns and three-six forfeiture
- Balanced, tactical and champion AI scoring
- Local match persistence in `user://ludo_pro_save.cfg`

## Android APK
Install Godot 4.4 export templates and configure Android SDK/JDK in Editor Settings. Create an Android export preset and export a debug APK. A signed release requires a user-owned keystore.

**Release status:** the native source and CI rules checks are not a substitute for a built APK or physical-device QA. Android export, touch testing and performance checks on real hardware must be completed before calling this release-ready.
