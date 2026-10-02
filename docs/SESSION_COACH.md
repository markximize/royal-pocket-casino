# Session Coach

The coach is a deterministic, offline explanation of recorded play and practice. It uses no network, account, telemetry, language model, random feedback or prediction of the next hand. Blackjack rules and payouts are unchanged.

## Evidence boundaries

Normal play is graded against basic strategy in OFF/BASIC, or in ADVANCED with Deviation prompts OFF. ADVANCED with prompts ON uses the compact supported count policy when triggered. Hidden strategy/count displays do not change that selected policy. Turning prompts OFF changes advice and grading together; no concealed alternative contradicts the visible basic recommendation.

Decision quality, wager behavior and results have separate records. A loss cannot reduce strategy accuracy. A win cannot increase it. Normal decisions use the existing rules-aware basic adviser; the supported count deviation, when applicable, is scored separately. Following a correct deviation is excluded from the basic-strategy denominator, so it cannot become a false basic-strategy mistake.

Hard totals, soft totals and pairs each retain attempts and correct answers. A double-related decision also contributes to the double subcategory when Double was recommended or chosen. The normal-play double subcategory overlaps its hard/soft/pair category and is never added twice to overall accuracy. Targeted double drills instead use the exclusive `practice.double` bucket: they improve double evidence and contribute once to overall practice accuracy. Applicable deviations have their own attempts/correct score. Unsupported deviation profiles do not create deviation evidence.

Normal decisions and trainer answers are stored separately (`play` and `practice`). Practice is recorded only after an answer is acknowledged by the existing save transaction. A cancelled question contributes nothing. Running-count and true-count accuracy remain separate. Answers made with hints are still practice evidence; these numbers do not certify unaided skill.

The coach displays combined recorded play/practice basic accuracy, and its category priorities use both sources. No old decisions, wagers or upcard patterns are reconstructed from aggregate legacy statistics. The existing lifetime gameplay ledger remains authoritative for per-hand wins, losses, pushes and bankroll. Coach results describe **round net outcomes**: a split round with one win and one loss may have a zero-net round even though two hands were settled.

## Practice priorities

- A strategy/category or deviation weakness needs at least **10 recorded answers**.
- Running-count or true-count weakness needs at least **5 recorded answers**.
- At least one recorded mistake is required; perfect or insufficient samples produce no invented weakness.
- Prefer an eligible weakness in the current session. Otherwise use the eligible lifetime sample.
- Choose the lowest correct/attempt ratio. Equal ratios use the fixed order: soft totals, pairs, hard totals, doubles, deviations, running count, true count, mixed strategy.
- Recommend **20 drills** in that category. Controller navigation opens the corresponding trainer where its category is available.

These are small coaching heuristics, not confidence intervals or a diagnosis of skill. A small sample can still be unrepresentative. Displayed percentages are rounded to the nearest whole percent for readability; scoring retains exact integer attempts/correct values. Dealer-upcard weakness is not recorded in this bounded version and must not be invented in feedback.

## Wager-pattern methodology

The current session retains its latest **40 completed, non-void rounds**, each with actual opening bet, opening bankroll, total stake including split/double additions, aggregate net and aggregate outcome. Pattern messages need at least **5 rounds**. All thresholds live together in `src/progress/betting_analysis.lua`; UI code does not choose them.

| Pattern | Required evidence in the retained window |
| --- | --- |
| Martingale-like | At least three consecutive transitions following losses where the next opening wager is 180%–220% of the previous opening wager. Five total rounds are still required. |
| Loss-chasing-like | At least three opening-wager increases immediately after losses. Used when the near-doubling condition is absent. |
| Drawdown progression | At least three opening-wager increases while cumulative window net is below an earlier window peak, when the loss-increase condition is absent. An individual win need not end a drawdown. |
| Oversized exposure | At least two rounds stake **over 10%** of opening bankroll, including split and double stakes. Exactly 10% does not trigger it. |
| Variable/erratic sizing | At least four wager transitions change by at least 50% of the preceding wager, with at least three direction reversals among those large changes. |
| Consistent restrained sizing | At least ten rounds, all retained opening wagers equal, and no round stakes over 10% of opening bankroll. |

Reports also retain counts of transitions after wins/losses, wager increases in each case, and increases while below the window peak. One occasional wager change does not meet the repeated-pattern rules. Wins after a progression do not erase the behavior, and no message says a betting system guarantees profit. A pattern label describes the observed sequence, not the player's intent, addiction, real-world finances or future results. Counts and shoe composition can change; increasing the wager itself does not improve a hand's winning probability.

These conservative project thresholds are explicit product heuristics. They are not a mathematically proven risk model, a gambling assessment or financial advice. The 40-round window can omit older context. “No repeated pattern met the threshold” is not a claim that a betting approach is safe.

## Sessions, history and results

A session ends only when the owner selects **New Session**. Quitting/restarting does not create or close a session. This avoids fragments caused by handheld suspend or a quick restart. Closing an empty session does nothing. The coach retains the latest **15 completed session summaries**, a current summary and lifetime coaching aggregates; old history drops from the beginning while lifetime totals remain.

Sessions use increasing local IDs rather than timestamps. Results retain round wins/losses/pushes, natural Blackjacks, aggregate net/stakes, biggest round win/loss, current/best win/loss streaks and drawdown. Drawdown is peak cumulative recorded net minus current net. Maximum drawdown retains the largest such difference. Chip grants are excluded from result net and drawdown, so a refill is not falsely treated as a winning round. This history begins when format-3 observation starts; it is not a reconstruction of old bankroll peaks.

## Save compatibility and validation

Progress format **3**, app **0.1.0-preview.4**, keeps engine version **1**. `migrations.to_current` first adds existing version-2 trainer defaults to a valid version-1 snapshot, then adds format-3 fields to either older snapshot:

- `assistance`: mode OFF and four granular preferences (strategy hints, explanations, deviations, count checkpoints).
- `coach`: empty honest observation history with lifetime/current summaries.

Existing bankroll, cards, shoe order/cursor, rules, RNG, normal statistics, trainer statistics, sound/settings, local identity and revision ancestry are preserved. Loading migrates a private copy in memory; it does not draw a card or write files. Old payload decoding returns its original fields and checksum, preserving hash ancestry. The application's first accepted new-format save preserves the old format's exact source bytes using the established bounded backup/readback protocol. Save failures keep the acknowledged state, expose Retry and retry the same candidate once.

Validation requires exact fields, valid booleans/enums, bounded integer counters (maximum 1,000,000,000,000), correct ≤ attempts, consistent outcome totals, valid streak/drawdown relationships, sequential bounded history IDs, lifetime containment of correct **and incorrect** answers and complete recent totals while no history has expired. Double scores must fit their ordinary-category correct/mistake counts. Zero-round result fields must be zero. Wager records require legal opening bets, whole multiples of opening stakes and ordinary payouts; natural 3:2 returns are the documented exception. At 40 or fewer current rounds, wager-derived results must exactly match every current result field. After the wager window expires, retained outcomes/stakes must fit the whole current summary and the omitted net/stakes must remain possible. Excess or malformed histories are rejected, not trimmed during loading. Normal save corruption/recovery remains the existing save-store responsibility; the coach never repairs a bankroll.

## Module ownership

| Module | Responsibility |
| --- | --- |
| `progress/session_coach` | Pure copy-on-write recording and session/history boundaries. |
| `progress/coach_summary` | Small score/result structures and invariant checks. |
| `progress/coach_validation` | Exact aggregate/history/wager consistency checks. |
| `progress/betting_analysis` | Explicit recent-window pattern thresholds and evidence. |
| `progress/coach_report` | Deterministic minimum-sample priorities and readable report data. |
| `app/session` | Record evidence with the accepted gameplay/trainer transaction and persist it once. |

The Blackjack engine contains no coaching UI, device controls, save paths or outcome-based strategy scores.
