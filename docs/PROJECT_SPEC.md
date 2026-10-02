# PROJECT_SPEC

**Status:** owner-authorized final hardware polish; preview.4 device approval pending. **Specification revision:** 4. **Date:** 2026-10-02.

The owner explicitly selected the first playable desktop prototype on 2026-10-01 and approved integrated Blackjack/Basic Strategy/Hi-Lo training on 2026-10-02. The latest final-polish request reports preview.3 successfully launched and normal Blackjack physically played on RG35XX H/muOS using PortMaster. It explicitly authorizes the bounded learning/audio/focus changes below without a rewrite. That owner report establishes prior-build evidence, not physical approval of preview.4. See [final verification](../artifacts/polish-evidence/FINAL_VERIFICATION.md) and [HANDHELD_TEST](HANDHELD_TEST.md) for the new artifact's evidence and next gate.

## Product boundary

Royal Pocket Casino, by MarkXimize Interactive, is a premium-feeling offline game and learning tool. V0.1 delivers one local human seat playing Blackjack against a dealer, a Basic Strategy Trainer, and Hi-Lo running/true-count training. There are no AI opponents, multiplayer tables, or other casino games.

There is no real-money wagering, deposit, withdrawal, redeemable currency, crypto gambling, cash prize, or transfer of chips for value. Chips exist only for entertainment and local progression. No login or Internet connection is required to play an installed native release.

The initial goal is a useful game that people voluntarily install and retain. Donations, sponsorship, paid editions, or cosmetic content may be considered later. V0.1 contains no ads, purchases, payment integration, purchase-linked chip grants, paid gameplay unlocks, telemetry, or manipulative retention mechanisms.

## Release scope

| Area | Proposed V0.1 requirement |
| --- | --- |
| Play | Virtual bankroll, betting, deal, Hit, Stand, Double, Split, natural Blackjack, bust, push, and exact settlement |
| Rules | One approved preset plus the bounded configuration matrix in BLACKJACK_RULES; no arbitrary rule scripting |
| Dealer/shoe | Correct dealer play, multiple decks, deterministic dealing, cut-card penetration, and shuffle between rounds |
| Persistence | Validated versioned local saves, active-round resume if approved, recovery, backups, and statistics |
| Learning polish | OFF/BASIC/ADVANCED Assisted Play, Learn Hi-Lo onboarding, four sourced deviations under supported rules, targeted practice and offline Session Coach |
| Input | Complete controller navigation on RG35XX H; keyboard for development |
| Presentation | Readable 640×480 table and menus, polished restrained motion/audio, visible rules and bankroll |
| Configuration | Audio levels, reduced motion, text/readability options, and controller mapping where validated |
| Distribution | Source and tested handheld package; a desktop development build precedes handheld polish |

The final-polish authorization retains **Blackjack, Basic Strategy and Hi-Lo** as the only gameplay/training foundation. It adds beginner onboarding and optional in-play learning, repairs the confirmed next-round controller-focus bug, improves original audio and integrates the supplied logo/credits. Blackjack rules, chip units, settlement, shoe RNG and the established save/launcher route remain authoritative. No new casino game or platform is authorized.

Assisted Play defaults OFF: no normal-table strategy/count/deviation assistance. BASIC uses the current-rule adviser. ADVANCED adds independently configurable public-card count displays/checkpoints and the compact supported deviation subset. [LEARNING_GUIDE](LEARNING_GUIDE.md) records source indices and their strict profile/estimator limits; unsupported combinations keep basic advice. The locked half-deck ceiling/minimum 0.5 and signed truncation convention is unchanged.

Session Coach keeps decision accuracy, wager behavior and results separate. Minimum samples and neutral pattern thresholds are explicit; outcomes never award or remove strategy correctness. Format 3 preserves existing saves and begins new observation history empty. The owner selects New Session explicitly, between rounds: restart does not close a session. Retain 15 completed summaries and 40 current-session wager observations, without raw unbounded replay data. See [SESSION_COACH](SESSION_COACH.md). Web, Android, accounts, cloud and every additional game/count system remain future milestones.

Excluded: Roulette, Slots, Video Poker, Craps, side bets, achievements, complex progression, game hub/downloader, plugin framework, marketplace, authentication, cloud services, microservices, and monetization systems. Do not add placeholder implementations for them.

## Targets and support claims

- Baseline: RG35XX H / H700 / approximately 1 GB RAM / 640×480 / controller / muOS / PortMaster-style distribution.
- Development: Windows and Linux desktop with the same Blackjack engine and fixtures.
- Later official releases: Web, then Android APK. Desktop consumer releases are optional after the development build is stable.
- Optional synchronization is a separate future milestone, not a dependency of any release above.

Record actual firmware, runtime, CPU architecture, storage medium, and controller mapping for every hardware result. A package launching on a different H700 handheld does not establish RG35XX H support. A successful export is not a successful device test.

## User experience constraints

Use dark surroundings, deep green felt, restrained gold, ivory cards, readable typography, subtle shadows and animations, and modest celebrations. No flashing-heavy effects, ad-like controls, currency imagery implying real value, or visual clutter.

Design first at native 640×480. Proposed minimum ordinary text is 18 pixels and essential values 24 pixels; test the actual font on the device, since pixel size alone does not ensure readability. Use distinct suit shapes and rank labels; never communicate legality, win/loss, focus, or suit solely by color. Show totals, bets, active split hand, available actions, and active table rules clearly.

Recommended initial control model: D-pad moves focus; A confirms; B returns/cancels before commitment; Start opens the pause/menu view; X/Y and shoulders may provide labeled shortcuts. No shortcut may bypass legality checks. Do not assign a destructive or costly action to an unlabeled button. Respect the firmware/PortMaster exit chord. Confirm actual button labels and mapping in the hardware experiment before fixing bindings.

Touch targets and safe areas are platform presentation concerns. Proposed later touch minimum is 48 logical pixels, subject to device testing. Every core action must also be reachable through focus navigation. Volume, mute, reduced motion, and readable suit/card options are release requirements. Assess remapping feasibility and screen reader limitations honestly; a canvas game is not automatically screen-reader accessible.

## Proposed performance budgets

These are acceptance targets, not measurements. OD-07 approves or revises them after compatibility experiments.

| Metric on RG35XX H | Proposed target and measurement |
| --- | --- |
| Startup | Interactive menu within 5 seconds from launcher start; report cold and warm timings separately across at least 10 launches |
| Memory | Resident process memory at or below 128 MiB in ordinary play, below 192 MiB peak in a 30-minute session; record runtime children and available system memory too |
| Frame pacing | Target 60 FPS; 99th percentile presented-frame interval at or below 20 ms during representative animation; no recurring pauses over 50 ms |
| Input | Visible acknowledgement within 100 ms under normal load, including save acknowledgement where required |
| Saves | Normally below 256 KiB; p95 complete commit within 100 ms on the approved SD card; report maximum and failure cases |
| Package | Game content target below 30 MiB, excluding shared runtime; record runtime download/storage separately |
| Domain | Ordinary action below 5 ms in device profiling; never execute large simulations in the render loop |

If 60 FPS cannot be achieved responsibly, propose a deliberate 30 FPS mode with measured pacing and owner approval; do not quietly reduce the claim. A failed budget prompts measurement and a localized change, not a new architecture by default.

Prefer cached fonts, small card/chip atlases, and reused assets. A 1024×1024 RGBA8 texture occupies about 4 MiB before mipmaps/copies; a 2048×2048 one about 16 MiB. Start with textures no larger than 1024×1024 unless measured justification exists. Avoid full-screen blur, particle storms, large videos, busy polling, and allocation-heavy work each frame. Do not save every frame or repeatedly decode fonts/textures.

## Owner decisions

The approved Blackjack rules/economy and active-decision save policy remain unchanged. The owner reports the prior native build working on hardware and explicitly authorizes this polish pass. OD-03/08 now include the bounded learning/coach changes and sourced deviation subset; no routine implementation reapproval is required. New-artifact physical QA, measured budgets/durability, public licensing, human review and strategy-profile comparison remain release decisions. A launch report alone does not prove SD power-loss safety or every proposed performance budget.

| ID | Required decision | Recommendation | Consequence |
| --- | --- | --- | --- |
| OD-01 | Technology and platform tradeoff | LÖVE + portable Lua, conditional on POC-01 through POC-04; accept community Web maintenance risk only if its spike succeeds | If official browser tooling is a hard priority or the spike fails, compare Godot on the actual device before choosing |
| OD-02 | Blackjack preset and configurable variants | Approve every proposed value in BLACKJACK_RULES; initially expose only decks 6/8, S17/H17, double any-two/9–11/10–11, DAS on/off, and penetration 50/67/75 percent | All additional variant support needs a separate scoped decision and tests |
| OD-03 | Trainer release scope | **Resolved:** the three existing experiences plus explicitly requested onboarding, Assisted Play and Session Coach | Preserve the engine; no additional casino games or platforms |
| OD-04 | Chip economy | One chip = 10 integer units; whole-chip bets in steps of 5; start 1,000 chips; table minimum 5, maximum 100; no negative balance | Also approve a free manual refill to 1,000 when available balance is below the table minimum, between rounds only; record the added units and retain statistics; no paid refill or daily lock |
| OD-05 | Interrupted rounds and save failure | Resume the last committed domain state, including shoe and active round; pause money-changing play when persistence fails | Simpler between-round saving would lose/rollback progress on interruptions and needs an explicit alternative policy |
| OD-06 | Licensing and contribution terms | Select source, original assets, docs, marks, official-build permissions, and inbound contribution policy separately | No LICENSE is chosen here; resolve redistribution rights before public release |
| OD-07 | Acceptance budgets and support matrix | Adopt proposed budgets; nominate an RG35XX H, exact muOS release, SD card, and tester; define later browser and Android versions at those milestones | Hardware evidence is mandatory for handheld support, not assumed from CI |
| OD-08 | Strategy/count teaching approach | Keep current-rule basic policy and locked exposed-card Hi-Lo convention; authorize four positive Illustrious 18 stand indices for the documented supported profile | Source-estimator difference and restricted basic-profile optimality remain documented limits; no invented indices or additional count systems |
| OD-09 | Uncommon-rule exclusions and failure policy | No insurance/even money/surrender in V0.1; US peek only; same-rank split, max four hands, no resplit aces/hit split aces; exhaustion voids/refunds the round | Approve the remainder of the rules inventory, including disabled variants, dealing order, auto-stop at 21, and no forced shuffle within a live round |

Do not ask the owner to approve cloud infrastructure, future game rules, or monetization technology now. They do not block this foundation.

## Proof-of-concept register

The isolated diagnostic record remains historical. The owner subsequently reports preview.3 launch and normal Blackjack play on the physical RG35XX H/muOS through PortMaster. Preview.4 still needs its focused physical checklist. Portable known-answer, payout and save scenarios are part of the native suite; exact final executions belong in [FINAL_VERIFICATION](../artifacts/polish-evidence/FINAL_VERIFICATION.md). Web/Android and controlled SD durability/performance experiments remain unclaimed. Keep experiments bounded and distinguish owner-reported play from instrumented budgets.

| ID | Experiment | Acceptance evidence |
| --- | --- | --- |
| POC-01 | RG35XX H LÖVE runtime, graphics, audio, and controls | Launch a 640×480 screen on the nominated muOS version; test all buttons, exit/relaunch, writable data path, and audio. Capture frame pacing, startup, memory, runtime identity/hash, and graphics backend. No assumption that desktop OpenGL works |
| POC-02 | Lua portability and exact-number contract | Run identical tiny fixture, integer payout checks, shuffle known-answer vectors, JSON round-trip, and replay checksum in desktop LuaJIT, Lua 5.1, handheld runtime, and browser build. Same outputs; no native modules/FFI required by core |
| POC-03 | Browser delivery and persistence | Small LÖVE/love.js screen on proposed Chromium, Firefox, and Safari versions; real IndexedDB commit across full browser restart, quota failure, input/audio gesture, and offline cached relaunch after first installation. Record headers, memory, load size, toolchain, and reproducible build route |
| POC-04 | Native storage durability/performance | A/B generations with crash injection, interrupted writes, out-of-space failure, readback, and recovery on actual SD storage; establish whether flush/rename/fsync is exposed and practical. State process-crash versus sudden-power-loss guarantees separately |
| POC-05 | Android route | Before substantial platform-specific presentation work, produce a tiny branded test APK using the upstream embedding route; verify signing/update identity, app-private persistence, pause/kill/resume, touch, audio, and offline relaunch on a real nominated device |
| POC-06 | Strategy provenance | Review implemented basic policy and exact deviation-profile/estimator assumptions against independent sources before public optimality claims; retained tests and cited facts do not replace that comparison |

POC-01/02/04 remain relevant native-release gates; POC-03 (Web) is deferred beyond locked V0.1. The owner's desktop-prototype authorization explicitly permits engine/desktop work ahead of these gates; it does not waive them for official releases. POC-05 is a short feasibility gate before substantial Android presentation work; Android release remains a later milestone. POC-06 governs strategy provenance/review; the candidate implements the documented policy with its restricted-profile comparison limitation, not a claim of independently solved optimality. Timebox investigations (initially one or two working days each); if blocked, record the blocker and reopen the decision rather than starting an engine fork. If LÖVE fails, run an equivalent minimal Godot compatibility test; raylib is the next alternative only with an accepted C/toolchain learning cost.

## Milestone roadmap

| Milestone | Deliverable | Exit condition |
| --- | --- | --- |
| M0 — Architecture | This small specification set and recorded owner decisions | OD-01–09 resolved; no implementation in this task |
| M1 — Compatibility | POC-01–04 and Android feasibility POC-05 | Stack accepted with exact versions and limitations; failed gates resolved |
| M2 — Tested Blackjack engine | Pure cards/hands/rules/shoe/round/settlement plus exact money and deterministic fixtures | TEST_PLAN domain cases and invariants pass; independent review and owner explanation/review completed |
| M3 — First playable desktop/dev build | Minimal table, keyboard/controller actions, local saves, and statistics | End-to-end deal/split/double/settlement/resume works; no visual polish claim yet |
| M4 — RG35XX H build | Handheld input, launcher integration, storage location, performance evidence | Actual device play, exit/relaunch, save recovery, and baseline budgets verified |
| M5 — Polished V0.1 | Existing modes plus approved focus/audio/branding, Assisted Play, Learn Hi-Lo and Session Coach; one format-3 handheld package | Required tests/review pass; exact new artifact physically approved; budgets/licensing/release checks complete |
| M6 — Native V0.1 approval gate | Prepared candidate with tests, exact installation steps and physical checklist | Stop feature development and wait for owner device results; fix evidenced failures within frozen scope |
| M7 — Web | Browser input/storage adapter, cached offline use, export/import, web distribution | Browser support matrix tested; native save interchange and failure handling verified; separate future milestone after native V0.1 |
| M8 — Android | Touch/safe areas, lifecycle, signed APK and update testing | Real-device offline/resume/storage tests; declared permissions and notices verified |
| M9 — Optional sync, later | Separate specification, provider-managed authentication, explicit conflicts | Offline behavior remains; consent, privacy, identity linking, and backup/conflict policies approved before any backend work |

There are no delivery-date estimates until the compatibility and scope decisions are settled. Keep each milestone in small reviewable changes.

## Main risks and responses

| Risk | Response |
| --- | --- |
| Engine support does not equal H700 driver compatibility | Exact-device launch/performance gate; prefer established runtime route |
| Community browser port/toolchain becomes difficult to maintain | Reproducible browser spike now; retain portable core; reopen stack if maintaining the port requires a substantial engine fork |
| Native, LuaJIT, and browser semantics differ | Portable syntax, bounded integers, ordered traversal, versioned PRNG, known-answer vectors |
| Rule combinations outgrow readable code/test coverage | Bounded supported settings, reject unsupported profiles, add variants one at a time |
| Incorrect split/peek/natural precedence causes chip errors | Concrete settlement fixtures and independently checked expected values |
| SD power loss/browser eviction loses progress | A/B validated snapshots, explicit failure reporting, backups/export, qualified durability claims |
| Strategy trainer gives advice for wrong rules | Exact strategy-profile match; documented provenance; unavailable state when unsupported |
| Readability/polish fails at 640×480 | Native-resolution controller-first review early; measure fonts and focus on hardware |
| Solo review lacks independence | Require a second reviewer for important changes; report honestly when that review or hardware evidence is outstanding |
| Asset or runtime rights block distribution | Track provenance and permissions before imports; complete notices for runtime dependencies too |
| Future sync duplicates balances/statistics | Preserve identity/lineage/revision and whole-snapshot conflicts; never sum bankrolls |

## Evidence policy

Allowed claims are specific: tests passed at a named commit, static checks passed, a named simulation met stated criteria, review completed by a named reviewer, or hardware tested on a recorded device/firmware. Do not label AI review an independent professional audit. Do not claim certification or security assurance from running a scanner.

Remaining public-release decisions: license/redistribution permissions, reviewed strategy-profile limitations and exact new-artifact hardware/performance acceptance. The authorized polish implementation is not blocked on a new scope approval.
