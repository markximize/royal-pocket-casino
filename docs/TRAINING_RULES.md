# TRAINING_RULES

**Scope:** the owner explicitly authorizes preview.4 learning polish around the existing Basic Strategy and Hi-Lo modes: optional Assisted Play, beginner lessons, four sourced deviations and Session Coach. No other counting system, casino game or online service belongs to V0.1. Gameplay rules remain unchanged in [BLACKJACK_RULES](BLACKJACK_RULES.md).

## Basic Strategy

Training recommendations are total-dependent: use the current player's hand, the dealer's visible upcard and the configured rules. They do not inspect the dealer's hidden card, undrawn shoe, running count or other hidden information. This is basic strategy practice, not a composition-dependent solver or a promise about any one hand's result.

`src/training/basic_strategy.lua` owns advice only. Its `recommend(game)` returns `{ action, explanation, category }`; action is `hit`, `stand`, `double` or `split`, and category is `hard`, `soft` or `pair`. It returns `nil, reason` when there is no player decision or the profile is unsupported. It never draws cards or changes chips. The shared engine evaluates hands and supplies legal actions.

Check a matching pair before using its soft/hard total. If splitting is unavailable because of funds or the hand cap, use the unsplit total. If doubling is unavailable because of the rules, funds, split restrictions or a third card, use the chart's hit/stand fallback. Soft 18 and the H17 soft-19 double fall back to Stand; ordinary hard and lower-soft doubles fall back to Hit. Locked split Aces and finished hands have no advice.

The six- and eight-deck any-two profiles share the published multi-deck policy. S17/H17 and DAS remain real inputs: H17 changes hard 11 against Ace, soft 18 against 2 and soft 19 against 6; DAS changes the small-pair splits. Penetration does not select another basic-strategy chart. Surrender, insurance, no-peek and unsupported variants remain unavailable under the shared rule validator.

## Strategy provenance and verification boundary

Reviewed on 2026-10-02:

- Michael Shackleford's [4–8 deck strategy](https://wizardofodds.com/games/blackjack/strategy/4-decks/) provides the S17 policy, DAS differences, H17 adjustments and hand-cap fallback.
- Ken Smith's [Basic Strategy Engine](https://www.blackjackinfo.com/blackjack-basic-strategy-engine/) independently presents the six-deck H17 profile and distinguishes Double-else-Hit from Double-else-Stand. Its current calculator also offers restricted doubling.
- Hundred Percent Gambling's [six-deck S17, 9–11, DAS, peek](https://www.hundredpercentgambling.com/6d-s17-d9-das-peek.htm) and [six-deck S17, 10–11, DAS, peek](https://hundredpercentgambling.com/6d-s17-d10-das-peek.htm) were read directly from the publisher. Those tables retain the normal DAS pair choices and remove the prohibited doubles.

The last publisher's [chart index](https://www.hundredpercentgambling.com/basic-strategy-master.htm) assumes at most three hands, while this game's cap is four. Its restricted-double pages therefore cross-check the row policy rather than establish an identical complete rules profile. The engine's legal-action set enforces the actual four-hand cap; once splitting is unavailable, the adviser evaluates the unsplit total.

All explanations and code are written for this project. No source chart image, branding, JavaScript or other chart asset is imported or redistributed. These references establish the advice's provenance; they are not a qualified independent audit.

**Policy support:** all 72 approved gameplay combinations use the published multi-deck hard/soft/DAS pair policy, with the shared legal-action set selecting the documented fallback when Double or Split is unavailable. Six-deck S17/DAS restricted-double tables were checked explicitly. Applying the same pair policy and legal double fallback to eight decks and H17 with restricted doubles is an engineering inference from the multi-deck policy and published fallback convention, rather than a separately solved mathematical optimum for each restricted profile. Those cells still need an independent profile comparison before a public release claims complete strategy verification. This limitation belongs in review/release evidence; the offline trainer never requires these websites.

Unsupported future rules return a visible unavailable result rather than being interpreted as an existing profile. Before approving new rule semantics or claiming independently verified restricted-profile optimality, compare the exact pair and total policies against an independently published or independently computed profile, record the evidence here, and add boundary examples. Some original publisher pages could not be read because the network returned a gambling-category block page; it was not bypassed. `tests/strategy.lua` checks concrete hard, soft and pair examples, H17/DAS changes, restricted-double fallbacks, no hidden-card access, no mutation and all 72 configured gameplay combinations. A legality sweep does not independently prove expected-value optimality.

## Optional Assisted Play

OFF is the default and suppresses normal-table strategy recommendations, count displays/checkpoints and deviation prompts. BASIC uses the existing current-rule basic adviser and concise why explanations. ADVANCED builds on it with optional running/true/deck displays and supported count-adjusted advice. Strategy hints, explanations, deviations and Check My Count preferences persist independently; count HUD booleans remain the existing settings. An advanced player can hide every count display and still choose checkpoints.

Basic Strategy and count-adjusted play remain distinct in the UI and scoring. A supported deviation does not overwrite the basic chart. The compact profile `hi_lo_i18_s17_6d_positive_stands_v1` uses four positive Illustrious 18 stand indices only under its documented six-deck S17/any-two/DAS assumptions. Unsupported rules, soft/pair/split/three-card decisions and below-index counts retain basic advice rather than guessed deviations. [LEARNING_GUIDE](LEARNING_GUIDE.md) gives the exact facts, publisher sources and limits: the source uses nearest-half-deck estimates, while this game deliberately keeps the owner's ceiling convention. No source EV/advantage claim is transferred.

Hints use only the current player cards and public dealer upcard/count. Card animations pause normal guidance until the relevant faces are displayed; the saved hole card contributes nothing before reveal. Assistance changes no cards, RNG, legality, settlement or wagers. Recorded assisted choices are learning evidence, not certification of unaided skill.

## Hi-Lo

The owner approved these conventions on 2026-10-02. One system is implemented: **Hi-Lo**. Ranks 2–6 tag +1; 7–9 tag 0; 10/J/Q/K/A tag −1. A complete standard deck sums to zero. `hi_lo.observe` accepts public physical-card IDs, deduplicates them within a shoe generation, and resets only for a newer generation. It cannot inspect a shoe or a hidden dealer card.

For normal Blackjack, `app/count_view` combines previous completed-round discards with the cards in the displayed filtered view. It excludes the entire current round from the committed discard prefix first, because settlement can be saved before its reveal animation finishes. This prevents an already committed dealer hole/result from leaking into the displayed count. Every exposed split card counts once, including cards moved between hands. Counting is reconstructed after load; no second mutable count ledger controls Blackjack.

**Estimated decks remaining:** `max(0.5, ceil((deck_count − exposed_count / 52) / 0.5) × 0.5)`. Exposed cards are the only input to depletion. This deliberately differs from the exact physical shoe cursor when a hidden card has been dealt. The display says estimated decks and never looks up that card. Near the end, the minimum divisor is half a deck.

**True count:** running count divided by that estimate, **truncated toward zero**. Thus +2.8 becomes +2 and −2.8 becomes −2. The pure helper also tests floor as an explicit alternative, but V0.1 saves/settings use only the approved truncate/half-deck convention. Integer answers are checked against that convention, not a silently rounded floating-point display. A supplied estimated-deck value is shown during true-count questions: this drills division using the documented estimate, not visual estimation of a physical discard tray.

## Practice and controller behavior

Basic Strategy runs a separate ephemeral instance of the same `blackjack.round` engine with a copy of the current configured rules and a separate injected seed. It skips automatic naturals/21s until a legal decision exists. An answer records correct/incorrect immediately; Next applies the player's selected legal action and generates the next real decision. Practice funds exist only in that instance. Neither correct nor incorrect answers change normal bankroll, cards, shoe, RNG or gameplay statistics.

Hi-Lo drills use the same card catalog, shoe construction, shuffle generator and penetration rules. They reveal one card at a time. No alternate Blackjack implementation exists. Beginner shows optional tags/running count; Practice hides the count and checkpoints every ten cards; Advanced hides assistance and alternates running/true checkpoints. Card pace is slow (2.5 seconds), comfortable (1.5 seconds) or fast (0.7 seconds). Each checkpoint card stays visible for a complete chosen interval before the question opens. A long OS stall reveals at most one card instead of silently skipping a batch.

Pause, manual Check RC/TC and New shoe are available. At the cut, the final card remains visible and the drill pauses; check it, then explicitly start a new shoe. Count entry uses D-pad focus and A on −1/Submit/+1; X/Y adjust by one and L/R by five. No keyboard is required. B/Start returns home without scoring an unanswered question. Cancelling a checkpoint records nothing and begins a fresh ten-card interval. There is no timing score or speed claim.

Normal HUD running count, true count and estimated decks are independently configurable and default **off**; they display only in ADVANCED Assisted Play. The table-menu checks also require ADVANCED and the Check My Count preference, after visiting the table and finishing card animations. They pause play and grade an entered count without permanently displaying an answer. Settings, Home and trainers pause a normal card reveal; they do not fast-forward unseen cards. Returning resumes it. Count assistance never changes RNG, cards, shuffling, legal actions or payouts.

Learn Hi-Lo provides five progressive stages across 15 short pages, with two exercises per stage before ordinary Beginner Count Trainer practice. The same helpers teach tags, running count, half-deck estimates, signed truncation and a hidden-then-revealed dealer example. Wrong answers explain the expected value; repeated Submit cannot score twice. Tutorial exercises do not inflate trainer statistics. Targeted category practice and its 20-drill goal are driven by actual coach weaknesses, not random messages. See [LEARNING_GUIDE](LEARNING_GUIDE.md) and [SESSION_COACH](SESSION_COACH.md).

## Local statistics and persistence

Format-3 progress retains format-2 `training.strategy` and `training.counting` independently from the existing gameplay ledger. Strategy records attempts/correct/incorrect/current/best streak. Counting records total attempts, separate running/true attempts and correct answers, and combined current/best streak. Accuracy uses the appropriate attempts denominator; no-attempt accuracy displays a dash. A wrong answer resets the current streak. Assisted answers are practice records, not certification of unaided skill.

Format 3 also stores assistance preferences and bounded coach evidence. Normal strategy, applicable deviations, count accuracy, wagers and aggregate round outcomes stay separate; losses never reduce strategy correctness and wins never award it. New Session closes a nonempty summary explicitly between rounds; app restart retains it. Keep 15 completed summaries and 40 recent current-session wagers. Valid version-1/2 saves preserve bankroll, old counters and exact source backups, with new coaching observations honestly empty. Detailed thresholds and strict validation belong to [SESSION_COACH](SESSION_COACH.md).

Answers save through the same validate/write/readback/adopt protocol as normal play. A failed write exposes Retry, blocks advance/leave, and retries the exact candidate so the question is scored once. Active practice drills are deliberately not persisted: restarting ends the drill and retains all acknowledged statistics/preferences. Normal Blackjack still resumes its saved hand. No network, login or telemetry is involved. Strategy advice remains independent of counting so assistance cannot alter the basic-strategy answer.
