# V0.1 polish test candidate — 0.1.0-preview.4

The owner authorized this final polish of the Blackjack/learning suite. This private candidate adds original casino audio, the supplied logo/credits, Learn Hi-Lo, optional Assisted Play, a small documented deviation profile and offline Session Coach/history. It contains no other casino game, backend or monetization system. Web/Android and cloud remain future scope. The owner reports a previous build worked on the RG35XX H; preview.4 requires its own physical tests. Public licensing, measured handheld budgets and final human review remain pending.

The exact new artifacts are `artifacts/royal-pocket-casino-v0.1-polish-test.love` and `artifacts/royal-pocket-casino-v0.1-polish-rg35xx-h-test.zip`, with sibling `.sha256` records. Previous preview.3 artifacts/evidence are historical.

## Controls and play

Launch the Windows shortcut for the working tree, or open `royal-pocket-casino-v0.1-polish-test.love` using LÖVE 11.5 for the packaged candidate. The window is 640×480; the proposed handheld launcher requests fullscreen at the target's native resolution. The menu has eight entries, including Learn Hi-Lo. Settings provides Assisted Play, Session Coach and About/Credits.

| Input | Behavior |
| --- | --- |
| Arrows / SDL D-pad | Move focus and skip disabled buttons |
| Enter / Space / SDL A | Confirm; on the table, finish an active animation without making another move |
| Esc / SDL B; Tab / SDL Start | Return/home or table menu |
| H / S / D / P | Legal Hit / Stand / Double / Split; also answer strategy questions |
| Mouse left-click | Activate a visible button |
| Q / E or SDL L/R | Inspect settled split hands; count/tutorial entry −5/+5; coach/credits paging |
| X / Y (keyboard or SDL) | Count/tutorial entry −1/+1 |

These SDL labels are provisional for the new package: record real RG35XX H mappings even if an earlier build worked. No essential action requires a keyboard. Select has no required app action. Controller remapping and any firmware exit chord remain dependent on actual runtime/device evidence.

Blackjack starts at 1,000 virtual chips; bets 5–100 in steps of 5. Chips have no cash value. Select chips or −5/+5, then Deal. Original naturals pay 3:2 profit; ordinary wins 1:1; a push returns the stake. Split aces receive one card and ordinary 21 does not receive a natural premium. The approved bounded settings remain 6/8 decks, S17/H17, doubles any-two/9–11/10–11, DAS on/off and penetration 50/67/75%; rules/shuffle change only between rounds. Free manual refill appears below the table minimum and records a separate grant.

Original cached felt/wood/gold vector art, readable card/suit shapes, chips, deal/flip/dealer pacing, split-hand panels and result/net reporting remain. The owner-supplied PNG is displayed unchanged and loaded once, with no forced splash screen. About/Credits shows the application version, `© 2026 MarkXimize Interactive` and paginated included license notices. Original sounds use filtered paper noise, resonant chips, quiet navigation and restrained result cues. A winning natural has three short notes; ordinary 21 uses an ordinary win. Sound/volume/reduced-motion settings remain available. Reduced motion resolves presentation immediately; the durable engine never waits for an animation or sound callback to settle a payout. See [AUDIO_AND_BRANDING](AUDIO_AND_BRANDING.md).

## Training

Basic Strategy uses an isolated instance of the same round engine and active configured rules. It grades a legal action and gives a short explanation. Next continues with the selected action. Hi-Lo uses the shared shoe/card catalog with beginner/practice/advanced assistance, pace controls, running/true checkpoints and physical-button number entry. Normal RC/TC/estimated-deck HUD switches remain independent and off by default; they appear in ADVANCED Assisted Play. Menu count checks require ADVANCED, enabled checkpoints, a table visit and finished reveals.

[TRAINING_RULES](TRAINING_RULES.md) defines the approved half-deck ceiling/minimum 0.5 and truncation toward zero, tag values, exposure rules, statistics and provenance. Restricted H17/eight-deck strategy adaptations are documented policy inference; full independent exact-profile optimality comparison remains a public-release gate. A legality sweep does not prove mathematical optimality.

Training does not spend normal chips or advance its shoe/RNG. Gameplay counters and trainer counters are separate. Assisted answers count in the simple aggregate practice statistics; the figures do not certify unaided skill. Drills end on restart, while all acknowledged counters/preferences remain saved.

## Lessons, optional advice and Session Coach

Learn Hi-Lo provides five stages with fifteen short pages and ten fixed exercises. It teaches tags, running count, upward half-deck estimates, truncation toward zero and counting a dealer hole only after reveal. Enter whole-number answers with the labeled buttons, X/Y ±1 or L/R ±5; deck questions explicitly ask for half-deck steps. Incorrect feedback explains the expected answer before Next. Lessons are untimed and restart from the beginning when reopened; they do not add to timed-trainer statistics. [LEARNING_GUIDE](LEARNING_GUIDE.md) gives the exact teaching examples and the compact deviation profile.

Assisted Play defaults OFF. BASIC shows basic-strategy advice; ADVANCED can add public count/deck information and supported deviations. Strategy hints, explanations, deviation prompts and count checkpoints have individual preferences. OFF hides these assistance features without changing cards, rules or payouts. Moving off the table pauses card presentation, and advice waits for its public reveal; no hole card or undrawn card is used.

The count-adjusted profile encodes four positive hard-two-card Hit/Stand indices for the documented six-deck S17/any-two/DAS rules. Basic Strategy remains separately labeled. Unsupported rules keep basic advice and show an unavailable reason; the game does not substitute a nearby index profile. These published numerical indices are an educational policy under the game's upward exposed-card estimate, not an independently solved optimal policy or transferred publisher performance claim.

Session Coach separates strategy/count evidence, recent wager patterns and round results. It requires enough recorded answers before recommending twenty targeted drills. Double practice contributes once to accuracy. Five rounds are needed before repeated wager patterns are interpreted; a losing hand never turns a correct decision into a mistake. The latest forty non-void round observations support explicit conservative heuristics. These labels do not predict a win or infer intent.

Select New Session only at the betting screen to retain a completed summary. Restart does not close a session. The latest fifteen completed summaries, current summary and lifetime coaching aggregates are stored locally; legacy totals are not converted into invented decisions. Coach round-net wins/pushes/losses differ from the existing per-hand gameplay ledger when splits have mixed outcomes. [SESSION_COACH](SESSION_COACH.md) defines sample thresholds, categories, histories and wager-pattern limitations.

## Responsibility and learning path

`blackjack/` owns one pure authoritative game. `training/basic_strategy` returns ordinary advice; `training/hi_lo` observes exposed IDs; `training/deviations` owns the bounded profile; `training/tutorial` owns fixed lessons; and `training/practice` owns temporary exercises. `progress/session_coach` records coaching evidence and delegates focused validation/report modules. `app/session` owns durable transactions; `app/training` connects answer/retry navigation; `app/education` routes lessons/advice/coach/credits; and `app/count_view` reconstructs public exposure while excluding unshown current-round discards. `ui/presentation` masks cards/results only after a committed game action; `ui/*` draws them. Preferences/counters stay current even while the table's reveal is paused off-screen. None of the UI/audio modules changes the Blackjack engine.

For learning, read `hand.lua` and its Ace scenarios first, then `hi_lo.lua` and `tests/counting.lua`. Trace a strategy answer through `basic_strategy` → `app/training` → `session.training_answer` → `training_statistics` → save/readback → feedback. In Lua arrays start at 1; `ipairs` gives ordered list traversal; a module returns a table of functions. No class framework, event bus, server or alternative game engine is involved.

## Saves and safe updates

Normal Windows progress remains in `%APPDATA%\LOVE\royal-pocket-casino-desktop-preview\`. Tests, compatibility PoC, graphical smoke and visual fixtures use separate identities. Run one normal instance at a time; sequential stale-writer checks do not constitute an OS concurrent-writer lock.

`save_a.json` and `save_b.json` alternate whole validated SHA-256 JSON envelopes. Format 3 adds `assistance` and `coach`; format 2's `training`/`count_settings`, engine 1, chip scale 10 and the gameplay ledger are retained. Validated v1/v2 loads migrate a private copy in memory without writing or changing normal game, IDs, revision or original checksum. Existing trainer totals/preferences are preserved where present. Assistance starts OFF and coaching observations start empty, because old aggregate totals cannot reconstruct decisions or wagers. The first accepted format-3 commit preserves the old payload's exact bytes in `backup_format_1.json` or `backup_format_2.json` before writing the alternate slot. Truncated migration-backup bytes are preserved in a bounded recovery copy before repair. A different valid/newer backup or different recovery copy blocks writes so it can be copied aside safely, rather than overwritten.

Accepted play, preferences, coach evidence/session closure and trainer answers commit before adoption. Pending writes block further transactions; Retry reconciles the exact candidate, so no duplicate payment, score or history entry occurs. Numeric counter limits reject a change while preserving acknowledged progress. Animations reveal only the committed filtered view. Menu/Home/training pause a normal reveal; settings saves/retries cannot disclose its hidden cards. Restart resumes the last durable normal hand/result without paying twice. Tutorial exercises remain temporary and do not write progress.

Corrupt newest slot recovers an older valid revision with a visible warning and preserved damaged bytes. Two bad slots or an unknown newer format block play and preserve files. No reset, arbitrary Lua evaluation, or guessed fields are used. Envelope/input reads are bounded to 1 MiB. Close and copy the whole save folder for manual backup. A/B plus close/readback is a recovery protocol, **not** a guarantee of SD-card sudden-power-loss durability.

## Verification and remaining gates

Local environment: Windows, official LÖVE 11.5/LuaJIT, StyLua 2.5.2 and Luacheck 1.2.0 in Lua 5.1 mode. Required checks are in `tools/check.ps1`; source/handheld builders exclude local tools, personal saves, firmware and runtimes. Separate AI review found exposure/retry/migration-size and coach-history/scoring issues; fixes have focused regressions. This is independent AI code review, not human review or a professional audit.

Use the [final preview.4 verification record](../artifacts/polish-evidence/FINAL_VERIFICATION.md) for final source/package test totals, simulations, graphical runs, hashes and outstanding checks. If the record has not been produced, final verification is pending. Do not reuse preview.3's numerical results as proof of this updated package. A successful audio call does not establish sound quality; a person must listen on desktop and handheld. The owner's earlier hardware success is owner-reported evidence for that previous build, while preview.4 mappings, saves, frame pacing, texture/audio resource use and stability require a new device record.

Desktop screenshot capture adds overhead: loop FPS/p99 is not presented-frame timing or input latency, and Lua heap is not process RAM. Hosted GitHub Actions/Ubuntu Lua 5.1, exact-profile strategy optimality, public licensing, real SD sudden-power-loss durability and hardware budgets require their own evidence. Follow [HANDHELD_TEST](HANDHELD_TEST.md), including its focused 10–15-minute polish checklist. Stop after preparing the candidate and wait for the owner's actual results.

## Historical preview.3 verification

The preview.3 source/package record on 2026-10-02 reported **282 passed, zero failed** (including 36 distribution gates), **10,000 simulated rounds** with 386 splits/765 doubles and zero invariant violations, and **40,000 fresh shuffles** within predeclared bounds. StyLua passed; Luacheck reported zero warnings/errors in 55 files; the portable-core boundary passed. Pinned-tool checksums and PowerShell parsing passed. Source/archive bytes, ZIP CRC/layout, unchanged JSON dependency, launcher LF/no BOM and stored Unix 0755 mode were verified. Bash/WSL was unavailable locally, so Bash execution/syntax and hosted CI remained unrun. Separate static launcher review did not prove device execution. Historical evidence is under `artifacts/v01-evidence/`; its artifact hashes belong to those older packages. Audio creation/playback executed, but listening and physical mapping were not performed in those runs.

Large/million-round statistical validation, final strategy-profile comparison and release licensing remain separate public-release criteria in TEST_PLAN/DEFINITION_OF_DONE. Historical evidence does not approve the new polish package.


### Historical packaged Windows evidence

Two preview.3 18-second graphical runs exited 0 with empty error logs. Run 1 loaded revision 17/five completed rounds and saved revision 23/six rounds. Run 2 loaded revision 23/six rounds and saved revision 28/seven rounds. Strategy/RC/TC attempts persisted at two each after the first and three each after the second. The normal saved phase/bankroll also reloaded. These runs used the isolated `royal-pocket-casino-preview-smoke` identity, not the normal player save.

Observed report samples: FPS 60 and 58; loop p99 49.799/49.879 ms; maximum 67.002/66.622 ms; Lua heap 3391.7/3302.4 KiB. Screenshot encoding, save commits and menu transitions are included; these samples do not establish a stable 60 FPS rendering or latency budget. Zero controllers were attached, so no physical mapping was tested. Actual captures of title/table/results, strategy/count entry/feedback, settings/help/statistics were inspected. Known minor visual issue: the Saved locally footer crowds the training-statistics button border; this was recorded, not redesigned during the implementation freeze.

During that preview.3 verification session, the device file browser did not respond and no game/runtime was installed or launched remotely. Later owner-reported success of a previous build is distinct from those Windows-only checks. **Preview.4 still stops at its own physical-device test and human-listening gate.**
