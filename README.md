# Ludo Pro
Premium offline-first Ludo game built with vanilla JavaScript, Canvas 2D and CSS. No API keys, backend or runtime dependencies.

## Run
Open index.html in a modern browser, or run npm run serve and visit http://localhost:4173. Run engine tests with npm test.

## Features
- Four-color board, four tokens per player, safe squares, captures, extra turns, exact home entry and victory.
- Solo vs 3 AI, 2 humans + 2 AI, and 4-player local modes.
- Three AI strategy profiles. AI scores home progress, captures, safe positions and opponent threat distances.
- Responsive interface, local autosave, move log, match stats, rules and victory dialog.
- Offline game logic and localStorage saves. Google Fonts is an optional online enhancement; fallback fonts work offline.

Dice are not manipulated by AI. The computer chooses moves strategically; it does not alter outcomes. Online matchmaking, accounts, cloud saves and monetization are outside this local-play foundation.