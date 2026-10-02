# TEST_PLAN

**Status:** preview.4 keeps the existing domain/simulation/statistical corpus and adds focused polish/learning/coach/save regressions. Exact final runs and counts belong in [FINAL_VERIFICATION](../artifacts/polish-evidence/FINAL_VERIFICATION.md). The owner reports prior preview.3 normal Blackjack worked on RG35XX H; this new artifact still requires [physical QA](HANDHELD_TEST.md). Hosted CI, public strategy-reference comparison and human release review remain separate gates. Independent AI review is development evidence, not a professional audit.

## Test principles and tools

Test the portable domain without a display or real filesystem. The preview uses a small readable `tests/harness.lua` and explicit fixtures instead of installing Busted; core modules can run under plain compatible Lua, while `--self-test` runs all suites in headless LÖVE LuaJIT with native SHA-256 injected for save checks. **StyLua 2.5.2** is pinned for formatting. **Luacheck 1.2.0** is now pinned and runs with Lua 5.1 settings; it detects issues such as accidental globals/unused values, not Blackjack correctness. Busted is optional if the local harness becomes insufficient. Sources: [Busted](https://github.com/lunarmodules/busted), [StyLua](https://github.com/JohnnyMorganz/StyLua), [Luacheck](https://github.com/lunarmodules/luacheck).

Run the same fixture corpus under Lua 5.1 and LuaJIT in CI; run portable known-answer fixtures in the actual handheld/browser runtimes at their gates. Add small independent boundary checks for forbidden imports/APIs in `src/blackjack` and avoid broad lint suppressions. This private preview deliberately includes tests behind `--self-test`; normal startup never executes simulations. Decide diagnostic-test inclusion separately for official releases.

Tests use named cards, explicit stakes and complete approved rules. Test constructors may reduce setup repetition but must not hide the scenario. Expected amounts/outcomes come from the specification or separately checked arithmetic, not the implementation being tested.

## Layer 1: domain unit and scenario tests

| Area | Required scenarios/invariants |
| --- | --- |
| Cards/decks | All 52 rank/suit combinations per deck; unique physical IDs; correct 6/8-deck membership; rank/value distinction; invalid rank/suit/ID rejected |
| Shoe | Exact card conservation across undrawn/current/discard partitions; cursor bounds; no duplicate draws; production versus partial test fixture distinction |
| Shuffle | Permutation/multiplicity preserved; exact known-answer order for approved PRNG; seed/state replay; correct inclusive bounded indices; no random-comparator sort/modulo bias |
| Penetration | Integer cut calculation; immediately below/at/above cut; crossing mid-round finishes then shuffles; hidden hole counts toward cut; manual/settings shuffle only between rounds |
| Hand/Aces | All BLACKJACK_RULES example hands; several aces; soft becoming hard; 21 becoming bust; natural requires original two-card origin; every rank value |
| Deal/peek | P-D-P-D order; hole hidden; failed peek hides rank; Ace/10 peek before player actions; dealer natural vs player natural/non-natural; no peek on 2–9 |
| Hit/Stand | Hit draws exactly one; bust/21 ends hand; stand draws none; split-hand advancement; invalid/stale/post-result command leaves all state and RNG unchanged |
| Double | Eligible two-card totals for all three settings, soft-total definition, DAS on/off, one card then finish, insufficient funds, extra stake exact, no double for less/after hit/locked ace |
| Split | Same-rank eligibility; K+Q rejected; identical rank across suits accepted; max four hands; resplit ordering; child origin/stakes; insufficient funds; legal two-card timing |
| Split aces | Exactly one additional card each; A+10 ordinary 21; A+A replacement cannot resplit; no Hit/Double; deterministic draw order and advancement |
| Dealer | Hits hard/soft below 17; S17 stops A+6; H17 draws; ace re-evaluation after draw; bust; skips draws when every outcome determined; no cosmetic extra draws |
| Settlement | Natural versus ordinary 21; both naturals push; player bust loses even vs dealer bust; ordinary compare/win/push/loss; every split hand resolves; doubled loss/win/push |
| Chips | Exact 3:2 examples; stake/return/profit distinction; invalid fractions/NaN/infinity/negative; divisibility; maximum limits and aggregate overflow rejection; rejected command does not debit |
| Rule configuration | All 72 supported combinations validate; forbidden combos/values/unknown fields fail; live change rejected; between-round change starts new shoe; saved profile immutable |
| Exhaustion | Short fixture runs out on deal/Hit/Double/Split/dealer; explicit round void/refund; no random fallback/mid-round shuffle; no partial split payments/statistics |
| Statistics | Round versus final-hand denominators; natural/bust subsets; split/double stakes counted once; exactly once completion after save/retry; grants and voids separate |

Exercise supported action/settlement scenarios across the rule matrix, not just validation of a configuration object. Keep boundary cases independently readable instead of generating a large opaque test table.

### Concrete acceptance fixtures

| Given | When | Then |
| --- | --- | --- |
| Bankroll 10,000 units; bet 100; shoe A♠,10♥,K♦,9♣ | Deal | Original natural wins: debit 100, return 250, balance 10,150; one original settled hand and one natural |
| Bet 100; shoe A♠,A♥,K♦,Q♣ | Deal/peek | Both naturals push; return 100; no player decisions |
| Bet 100; player 8♠+8♦; dealer 10♥+7♣; next cards 10♣,9♦ | Split, stand first, stand second | Hands 18/17 vs 17; total debit 200, return 200+100; net +100; two settled hands, one win, one push |
| Bet 100; player A♠+A♦; dealer 9♥+8♣; next cards K♣,9♦ | Split | Both finish after one card; returns 200+200 against 17, not natural premiums; no split resumption |
| Bet 100; player 5♠+6♦; dealer 10♥+9♣; next card 9♣ | Double | Stake becomes 200; final 20 wins; return 400, net +200 |
| Player stands 18; dealer A+6; next card 2 | Dealer resolves | S17: player wins against 17; H17: dealer becomes soft 19 and player loses |
| Only 99 available units; current hand stake 100 | Double or split | Rejected; cards, bankroll, hand index, statistics and RNG state unchanged |
| Completed saved round already contains credits/statistics | Load, display result, next round | No second credit, stake debit or completed-round increment |

Illustrations of player/dealer hands can be fixture state constructors where testing actions directly; deal tests use ordered shoes. Full integration fixtures include valid complete production shoes. Expected sums are explicitly written and reviewed.

### Disabled features

V0.1 tests ensure insurance, even money, surrender, no-hole-card, resplit aces, equal-value splitting and unsupported payouts cannot accidentally be enabled through settings/save import/commands. Do not implement them solely to satisfy a test list.

Before any future enablement, add: insurance against Ace with natural/non-natural dealer, separate main wager push/loss, funding and exact B/2; even-money exclusivity/guaranteed result; late/early surrender timing and precedence; all no-peek original/added-bet loss exposures; ace/face split variants; trainer-profile coverage. The new approved rule revision defines expected values.

## Layer 2: integration, persistence and lifecycle

Use a memory/fault-injecting storage adapter for deterministic integration tests, then actual platform storage for lifecycle verification.

- Session accepts a command, computes its domain/statistics snapshot, commits once, and exposes the view only after acknowledgement.
- Rejected commands do not save, draw RNG or change state; duplicate/stale inputs cannot double-debit while a commit is pending.
- Save/load each stable phase, including betting, split progression, doubled hand, hidden dealer hole, reached-cut flag and settled result. Same next commands yield the same cards/outcomes after resume.
- Rule settings and shoe state agree; changing a supported setting between rounds creates a new profile/shoe, without changing existing totals.
- Decode/encode at numeric bounds and ordinary values; retain scale/profile ID; no float rounding, executable Lua, unauthorized fields, oversized/deep JSON, card duplicates or bad references.
- Reject or recover truncated file, invalid UTF-8/JSON, valid JSON with invalid schema, wrong checksum, tampered payload, mismatched product, illegal active state and unavailable RNG version.
- Inject failure before write, during truncation/write, at close, after possible commit but before acknowledgement, during readback and during adoption. Assert the loadable outcome is either the last valid snapshot or the complete candidate, never mixed bankroll/statistics/shoe revisions.
- Recovery selects same-profile/lineage valid revision; equal-revision/different-hash and unrelated profiles are explicit conflicts. Newer unknown schema is preserved and normal writes blocked.
- One corrupt slot recovers older with visible rollback; two corrupt slots preserve data and offer import/reset. Out-of-space/permission failure pauses committing play. Backups remain available after failure.
- Test real v1/v2-to-v3 migrations with independent expected defaults, exact old payload/hash preservation, protected original backups, failure/retry and idempotent repeated loading. Existing bankroll/round/shoe/RNG/old counters remain unchanged; do not invent old coach observations.
- Profile/device identities behave correctly on import to another installation; clocks going backward/offline/missing do not order snapshots. Manual restore starts a separate lineage.
- Statistics definitions/escrow relationships survive retries, restore, settings saves and grants. Round exhaustion removes all that round's wagering effects and increments only void count.

On native targets, kill/relaunch between accepted commands and while writing; measure actual recovery on the nominated SD card. Power-loss testing uses a controlled/disposable test save and records its limitations. Do not confuse process termination with removing electrical power.

On Web, test acknowledged IndexedDB persistence across full browser restart, refresh while saving, denied storage, quota, clearing/eviction, temporary mode, offline cached relaunch and two-tab writer rejection. No unload callback is relied on as the only save opportunity.

On Android, test app pause/resume, background kill, restart, installation update over a previous signed build, app-private storage, touch, audio and safe areas. APK assembly/signature checks and device launch are separate claims.

## Layer 3: simulation and statistical validation

Simulation checks impossible states, shuffle/distribution anomalies and chip accounting at scale. It does **not** prove the rules, strategy optimality, PRNG quality, casino fairness or mathematical house edge. A simulator can faithfully repeat the same bug as the engine.

### Deterministic state sweeps

For pull requests, initially target 10,000 rounds across a documented fixed seed set and representative supported profiles, with a bounded runtime measured at M2. Use two named drivers: a simple stand-at-17 policy and a legal-action exercise policy that deliberately visits splits/doubles/resplits. The driver has its own injected seed; it cannot alter domain legality or read hidden cards for ordinary decisions.

Every command/round must preserve card membership, finite/bounded integers, nonnegative available funds, legal phase/action progression, stable rule profile and exactly-once completion. For every summary independently sum literal debits/returns and compare the bankroll identity. Prohibit impossible extra naturals, payouts outside approved formulas, or statistics inconsistencies. Zero invariant violations is the criterion; no statistical tolerance permits these failures.

A longer nightly/pre-release suite targets at least 1,000,000 completed rounds spread over at least 100 seed streams, with different approved profiles and funding thresholds. Record completed/void counts, action/state coverage, seeds, policy/version, runtime versions and elapsed time. A time-limited/incomplete run is reported as incomplete, not passed. Run large jobs on development/CI hardware; the handheld gets short correctness/profiling runs.

A seed/corpus change is reviewed. On failure, export the minimal replay/checkpoint, reproduce it, minimize the scenario and add a named regression test. Do not rerun with another seed until a red result becomes green.

### Independent fresh-shoe experiments

Use a separate experiment with independent fresh shuffles/trials for analytic comparisons; **do not apply independent Bernoulli confidence intervals to consecutive hands in a depleted shoe**. Check rank/suit position marginals, natural frequency and rank-pair frequencies. Exact permutation/card multiplicity is tested first, since a rank histogram alone can miss a broken shuffle.

For D decks, N = 52D and an original two-card player natural has probability:

```text
p_natural = 2 × (4D / N) × (16D / (N − 1))
```

The player cards in P-D-P-D order still have this marginal probability under a uniform fresh shuffle. Six decks yield about **4.74895%**, eight about **4.74513%**. These are natural frequencies, not win rates or profit estimates.

Proposed long-run fresh-shuffle sample size is 1,000,000 trials; first measure its CI cost. If reduced, recalculate thresholds from the documented sample size; do not retain arbitrary old ranges. Descriptive six-standard-error windows at that size are:

| Observation | Analytic expectation | Approximate six-SE diagnostic window |
| --- | --- | --- |
| Six-deck original natural | 4.74895% | 4.6213%–4.8766% |
| Eight-deck original natural | 4.74513% | Use p ± 6√(p(1−p)/n), with n from the report |
| A named rank in the first position | 1/13 = 7.69231% | 7.5324%–7.8522% |
| A named suit in the first position | 1/4 = 25% | 24.7402%–25.2598% |

These windows help humans interpret magnitude. The formal gate is predeclared: use two-sided **exact binomial** acceptance bounds for each registered marginal/natural comparison, with family false-alarm budget alpha = 0.001 and Bonferroni allocation alpha/K, where K is the number of registered comparisons. Specify K, integer acceptance counts, sample size and seed list before execution. Use an independently trusted statistics tool/library to compute limits and record its version. Avoid calling a fixed-seed PRNG corpus genuinely independent random evidence; it is a reproducible diagnostic of the chosen generator/shuffle.

For pair/order tests, derive expected without-replacement probabilities. Predeclare position pairs and categories, combine sparse categories as justified, and use a valid multinomial/chi-square or exact test with minimum expected-cell counts documented. Include these tests in the alpha budget; adding tests after seeing results requires a new declared experiment, not selective reporting. A binomial confidence interval from each cell alone does not prove joint independence.

An anomaly triggers investigation of sample dependence, generator range/conversion, fixture construction and implementation; thresholds are not loosened without a reviewed mathematical justification. Report observed counts, expectation, interval/test, correction, seeds and limitations, not just “simulation passed.”

### Returns and long-run outcomes

There is no universal correct house edge/win-rate target for every player policy and ruleset. Initially gate exact accounting and outcome invariants; report profit/bust/push histograms descriptively.

An eventual expected-return experiment must identify rules, player policy (including action fallback/funding), penetration/shuffle model, bet size and stake normalization. Choose a redistributable independent reference or separate exact calculation. A separately implemented simplified no-split model may cross-check only that restricted case, never the full split game.

Because outcomes within a shoe are correlated, estimate uncertainty across independent seed/shoe batches, using batch means or an appropriate cluster/bootstrap method. Predeclare a practically meaningful error margin and sample-size plan based on pilot variance. Use held-out confirmation seeds after the pilot. Do not compare to an unexplained Internet percentage or interpret approximate agreement as proof.

## Required V0.1 trainer tests

Basic Strategy tests need independently reviewed full profile tables, provenance/redistribution rights, hard/soft/pair/surrender cases where supported, fallback actions when Double/Split unavailable, and explicit unavailable results for unsupported rules. Test that generated scenario legality agrees with the same engine.

Hi-Lo tests need all rank tags, zero total for a complete standard deck/shoe, hidden/revealed card boundaries, each exposed ID counted once, shuffle reset, drill scoring, and approved true-count/divisor/rounding cases. Loading a save cannot count previously exposed cards again. Counting, strategy, trainer integration and old-save migration suites are implemented and retained.

### Authorized final-polish regressions

| Area | Focused checks |
| --- | --- |
| Confirmed controller bug | Closing a completed round selects Deal; previous funded wager remains unchanged; D-pad/keyboard navigation and save retry still work. |
| Assisted Play | OFF/BASIC/ADVANCED visibility, granular persisted preferences, current-rule basic advice, unsupported deviation fallback and no hidden/revealing card leakage. |
| Learn Hi-Lo | Fifteen-page progression and ten independently expected answers; wrong-answer explanations, repeated Submit, exposed-hole practice, half-deck ceiling/minimum and positive/negative truncation; no normal bankroll/stat contamination. |
| Deviations | Below/at/above four sourced thresholds; explicit supported profile across all 72 rules; exclude soft/pair/split/three-card/unsupported cases; validate count conventions; no mutation or hidden access. Sources and estimator caveat: LEARNING_GUIDE. |
| Coach | Losing correct decisions versus winning mistakes, separate categories/deviation/count scores, double practice counted once, minimum samples, deterministic weakest-category recommendations and targeted drill behavior. |
| Betting patterns | Five-round/three-loss-increase gates, three near-doublings, false-positive cases, split/double exposure, erratic-direction thresholds, consistent sizing and drawdown behavior; outcomes do not grade strategy. |
| Coach persistence | 15-session/40-wager bounds, explicit session closure, restart retention, strict lifetime/recent/wager/result relationships, counter limits and failed-save scoring exactly once. |
| Migration | Valid betting/live v1 and v2 snapshots, old game/identity/hash preservation, new fields/defaults, protected backups and rejected malformed/mixed/newer schemas. |
| Audio | Original deterministic samples, finite amplitudes/fades, caching, cooldown/voice limits, mute/volume, no shoe RNG use, result cues only after display and unsupported-output fallback. Physical listening remains required. |
| Branding/UX | Supplied image aspect/resource behavior, actual build version, credits/notices readable at 640×480, controller-only new screens and Back; no forced startup delay. |

Do not remove meaningful old tests or change registered simulation seeds/statistical bounds to accept a regression. Re-run the complete required suite after final source changes, then test the built `.love` and exact handheld archive. Windows rendering/audio API execution is not physical listening or RG35XX H validation. Preserve the working launcher override and require update/migration on a copied save before testing the owner's main data.

## CI and release pipeline

The checked-in GitHub Actions workflow now defines Windows format/lint/boundary/full-suite/archive checks and an Ubuntu Lua 5.1 portable-domain job, with pinned checkout and hash-verified Windows tools. Hosted runs and Linux/device results are still pending; local success does not claim green CI. Give CI minimum permissions, separate untrusted pull-request checks from signing/release secrets, and never run contributor code with release credentials. Pin third-party actions to full commit SHAs and verify downloaded runtime/tool hashes. [GitHub Actions secure-use guidance](https://docs.github.com/en/actions/reference/security/secure-use).

| Stage | Required check | Blocking condition |
| --- | --- | --- |
| Specification | PR names applicable requirements/rules, scope and unanswered decisions | Unapproved semantics or scope expansion |
| Format/lint | StyLua check; Luacheck; forbidden domain dependencies; documentation links and whitespace | Formatting/static failures or unjustified suppressions |
| Unit | Lua 5.1/LuaJIT domain/financial/rules fixtures | Any scenario/invariant failure |
| Integration | Session/save/recovery/statistics fault cases; migration fixtures when applicable | Inconsistent/unsafe saved state or regressions |
| Short simulation | Fixed reviewed seed/profile corpus and exact invariants | Any violation or incomplete required run |
| Build/smoke | Reproducible `.love`/desktop dev artifact; later target builds and fixture runs | Missing files, bad paths/notices, start failure, unsupported runtime |
| Independent review | Separate reviewer checks domain/save changes and expected values | Material findings unresolved or review absent for important work |
| Fix/retest | Relevant checks rerun; full required suite after behavioral changes | Stale results or unresolved failures |
| Human review | Owner inspects the change, evidence and user behavior | Owner review incomplete |
| Pre-release simulation | Long invariant sweep, declared statistical tests and limitations | Invariant failure, unexplained anomaly or missing evidence |
| Hardware/browser gate | Exact artifact tested on support-matrix targets, with controller/readability/storage/budgets | Untested or failing claimed target |
| Release | License/notices, signed artifacts as appropriate, checksums, changelog, install/update/rollback notes and version tag | Missing rights, unsupported quality claims, incomplete release checklist |

Release evidence belongs to the final candidate commit and artifact checksum. A changed artifact invalidates its earlier hardware result. Documentation-only edits need link/content review, not a gratuitous million-round simulation. Changed payouts/shoe/saves require the relevant layers and broader regression suite; do not skip them because visuals look right.

Dependency/license/secret scanning is useful. Run vulnerability checks where tooling has actual coverage (e.g. native runtime, Android/JS packaging dependencies). Lua has limited ecosystem-wide vulnerability/static-type coverage; record scanner scope and unknowns. Do not label an empty report a security audit. Do not add a heavy scanner/build framework without a supported purpose.

## Evidence record

For each release preserve commit/tag, exact tool/runtime versions, artifact hashes, passed/failed/skipped checks, fixture and simulation configuration, reviewers, device/firmware/browser versions, startup/memory/frame/save measurements, install/update results, and known limitations. A compact CI artifact and release checklist are enough; do not generate dozens of reports that no one maintains.

Regression policy: every reproducible bug fix adds a focused test that fails before the fix and passes afterward. For visual/controller bugs, retain a reproducible manual scenario and an automated boundary test where meaningful. Only claim independent audit if a qualified third party actually performs one.

## Executed bounded fresh-shuffle diagnostic — V0.1 candidate

`tests/distribution.lua` is a headless diagnostic; normal startup does not run it. The plan and bounds below were declared before running the corpus on 2026-10-02. Each deck size uses **20,000 complete fresh shuffles**: 20 Park–Miller seed streams (`1001` through `1020`), each producing 1,000 shoes while retaining its generator state. The six- and eight-deck experiments each restart those specified streams. These seeds are a reproducible corpus, not genuinely independent random evidence.

The registered family has **36 comparisons**: for each deck size, 13 first-position rank counts, four first-position suit counts, and one original-player natural count. A natural checks ranks at positions 1 and 3 of P-D-P-D directly, without calling the production hand evaluator. Existing catalog/permutation tests remain necessary.

| Comparison | Independent uniform-shuffle probability | Inclusive acceptance counts out of 20,000 |
| --- | --- | --- |
| Each first rank, either deck size | 1/13 | 1,383–1,699 |
| Each first suit, either deck size | 1/4 | 4,745–5,258 |
| Six-deck original natural | 2 × 24 × 96 / (312 × 311) = 4,608/97,032 | 826–1,078 |
| Eight-deck original natural | 2 × 32 × 128 / (416 × 415) = 8,192/172,640 | 826–1,077 |

The nominal family false-alarm budget is 0.001, with Bonferroni allocation to two tails of every comparison: **per-tail alpha = 1/72,000**. Bounds were independently computed with Python **3.12.14**, standard-library `decimal` at 80 digits, from the exact-binomial PMF recurrence: start with `P(0) = (1−p)^n`; then `P(k+1) = P(k) × (n−k)/(k+1) × p/(1−p)`. Sum the PMF and select the first integer crossing each CDF target, alpha and 1−alpha. A separate standard-library `math.lgamma` log-PMF summation checked that both rejected tails stay below alpha and the adjacent exclusions would exceed it. No normal approximation or new dependency was used; SciPy was unavailable.

Executed results: **36 comparisons passed; zero failures** under the LuaJIT runtime bundled with official Windows LÖVE 11.5. The standalone diagnostic took **0.307 seconds**, excluding Python/DLL startup; this is a development-PC observation, not a handheld performance claim.

| Decks | First-rank counts in A,2,3,4,5,6,7,8,9,10,J,Q,K order | First-suit counts in S,H,D,C order | Naturals |
| --- | --- | --- | --- |
| 6 | 1516, 1506, 1579, 1540, 1542, 1535, 1617, 1535, 1552, 1546, 1510, 1507, 1515 | 5032, 5099, 4936, 4933 | 949 |
| 8 | 1586, 1607, 1514, 1508, 1560, 1513, 1561, 1573, 1487, 1527, 1504, 1525, 1535 | 5138, 4898, 4973, 4991 | 918 |

These nominal binomial gates assume independent uniform fresh trials; the seeded generator corpus does not establish that assumption. Passing detects no anomaly in these registered marginals at this sample size. It proves neither joint order independence, PRNG quality, expected return, house edge, strategy optimality nor casino fairness. The proposed million-round/long-run experiments above were **not executed** by this diagnostic. Investigate any future failure with the same corpus and add a focused regression; do not change seeds or widen bounds to obtain a pass.
