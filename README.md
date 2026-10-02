# Royal Pocket Casino

MarkXimize Interactive's offline Blackjack game and training suite. App **0.1.0-preview.4** is the owner's explicitly authorized hardware-polish candidate: the same Blackjack game, Basic Strategy and Hi-Lo practice, with optional Assisted Play, beginner lessons and a deterministic Session Coach. No additional casino game or online system is added.

The owner reports **PASS for the final preview.4 package on the physical RG35XX H**, following the supplied device checklist. This is owner-reported acceptance; no itemized logs or measured performance figures were supplied. The tested ZIP remains unchanged. Public-release licensing remains pending. See [the updated verification record](artifacts/polish-evidence/FINAL_VERIFICATION.md).

## Play on Windows

Double-click **Play Royal Pocket Casino.cmd**. It uses this workspace's portable LÖVE 11.5, or an installed `love.exe` on PATH. On another PC, install [LÖVE 11.5](https://love2d.org/) and open `artifacts/royal-pocket-casino-v0.1-polish-test.love`, or run `love .` from the repository.

Arrows/D-pad select; Enter/A confirms; Esc/B returns and Start opens/returns from menus. H/S/D/P are desktop Blackjack shortcuts. Trainers use separate practice cards/funding and cannot change the normal bankroll. Count entry supports X/Y ±1 and L/R ±5, with equivalent focus buttons. After closing a round, focus selects Deal and retains the previous funded wager.

Assisted Play defaults **OFF**. BASIC provides current-rule strategy hints and explanations; ADVANCED also enables optional public-card counting and the documented compact deviation profile. Granular preferences allow count displays to stay hidden while checkpoints remain available. Learn Hi-Lo teaches tags → running count → half-deck estimates → signed true count → public-card practice. Session Coach separates decisions, wager patterns and outcomes, and offers targeted practice after sufficient evidence. See the guides below for boundaries and controls.

## The one RG35XX H candidate

Use **artifacts/royal-pocket-casino-v0.1-polish-rg35xx-h-test.zip**. Follow [Wi-Fi installation and physical checklist](docs/HANDHELD_TEST.md). Transfer needs neither a cable nor a card reader. The source-only package requires the existing PortMaster LÖVE runtime and preserves the working `portmaster-path.txt` override to `/mnt/mmc/MUOS/PortMaster`. Keep the installed `data/` folder when updating. The owner reports this package passed physical testing. Its bundled instructions retain their pre-test wording to preserve the exact tested artifact.

The earlier isolated [compatibility diagnostic](experiments/love-compatibility/README.md) remains historical/diagnostic work. It is not a second current V0.1 game package. Desktop evidence cannot establish handheld compatibility.

## Engineering documents

| Document | Owns |
| --- | --- |
| [PROJECT_SPEC](docs/PROJECT_SPEC.md) | Frozen scope, platform gates, budgets and owner decisions |
| [BLACKJACK_RULES](docs/BLACKJACK_RULES.md) | One authoritative rules/dealing/settlement contract |
| [ARCHITECTURE](docs/ARCHITECTURE.md) | Engine, presentation, trainers and save responsibility boundaries |
| [CODING_STANDARD](docs/CODING_STANDARD.md) | Human-readable Lua, educational headers and review policy |
| [TEST_PLAN](docs/TEST_PLAN.md) | Deterministic, migration, simulation and statistical methodology |
| [DEFINITION_OF_DONE](docs/DEFINITION_OF_DONE.md) | Evidence required for features and releases |
| [LICENSING_DECISIONS](docs/LICENSING_DECISIONS.md) | Pending code, asset, branding and public distribution decisions |
| [TRAINING_RULES](docs/TRAINING_RULES.md) | Strategy provenance/fallback limits and approved counting conventions |
| [LEARNING_GUIDE](docs/LEARNING_GUIDE.md) | Beginner tutorial and four sourced deviation indices, profile assumptions and estimator caveat |
| [SESSION_COACH](docs/SESSION_COACH.md) | Scoring separation, pattern thresholds, practice priorities and bounded history |
| [AUDIO_AND_BRANDING](docs/AUDIO_AND_BRANDING.md) | Original sound recipes, resource limits, supplied logo and credit rights |
| [DESKTOP_PREVIEW](docs/DESKTOP_PREVIEW.md) | Candidate operation, save behavior and actual local evidence |

## Check and build

```powershell
& .\tools\setup-check-tools.ps1
& .\tools\check.ps1
& .\tools\build-handheld.ps1
```

Pinned Windows development tools stay in ignored `.local-tools/`; outputs stay in ignored `artifacts/`. Setup downloads only official sources and verifies hashes. Normal startup never runs tests or simulations. The checked-in GitHub Actions workflow is prepared; hosted CI has not run.

The engine uses a portable Lua 5.1 subset, injected deterministic randomness and exact integer chip units. Format-3 A/B saves add assistance preferences and coaching evidence without changing the engine or existing bankroll/progress. Valid format-1/2 saves migrate in memory; the first accepted new save preserves the original old-format bytes. Coaching begins with honest empty observations. **New Session** explicitly closes a nonempty coaching session; restarting the app does not. History retains 15 completed sessions and 40 recent current-session wager observations. Local player/device IDs are not accounts. Close the game and copy the entire save folder for backup; run one instance at a time.

Current test totals, Windows smoke results, package checks and remaining limits belong to [FINAL_VERIFICATION](artifacts/polish-evidence/FINAL_VERIFICATION.md). A successful Windows run is not a new RG35XX H test; AI review is not a professional audit.

No real-money wagering, purchases, advertisements, accounts, server, cloud, other casino games, extra count systems, Web build or Android build belongs to V0.1. All installed modes work offline. **The owner's hardware PASS is recorded; implementation remains frozen while public-release licensing/rights are unresolved.**
