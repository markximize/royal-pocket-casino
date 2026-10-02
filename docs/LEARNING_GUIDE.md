# LEARNING GUIDE

This V0.1 update adds beginner Hi-Lo lessons and a deliberately small count-adjusted play profile. Both are deterministic offline modules. They never draw normal-game cards, change a wager, settle a hand or read an undrawn shoe. Ordinary basic strategy remains a separate recommendation from `basic_strategy.lua`.

## Learn Hi-Lo

Assisted Play starts OFF. BASIC offers current-rule strategy; ADVANCED adds the supported profile and optional public-count displays. Strategy hints and explanations can be hidden independently. Turning **Deviation prompts OFF** selects ordinary basic advice and ordinary basic coaching for normal play, so following the displayed recommendation is never graded against a hidden alternative. With prompts ON, supported deviation decisions have their own score even when RC/TC displays are hidden. Unsupported profiles retain basic advice. Optional count checkpoints remain available with all three count displays OFF.

Tutorial completion opens temporary **Beginner**, tags-on, slow Count Trainer practice. It does not overwrite the saved trainer preferences. Coach recommendations instead open 20 drills in the recorded weak category; these are distinct from beginner onboarding.

`src/training/tutorial.lua` owns 15 short pages: five stages, each with one explanation and two exercises. The controller UI owns entry and Back; the module owns the question and feedback. A wrong answer explains the expected value before Next. Repeated Submit preserves the first answer. Restarting the tutorial starts the lessons again; tutorial exercises do not inflate timed-trainer statistics.

1. **Tags:** 2–6 add one; 7–9 are neutral; 10/J/Q/K/A subtract one. Start at zero after a shuffle.
2. **Running Count:** accumulate exposed-card tags. Low and high cards can cancel; neutral cards do not change the total.
3. **Estimated decks:** use exposed-card depletion, round upward to half-deck steps and keep a minimum half deck. A controller question asks for the number of half-deck steps: six steps means three decks.
4. **True Count:** divide Running Count by estimated decks and truncate toward zero. +2.8 becomes +2; −2.8 becomes −2.
5. **Table practice:** player 5+6 and dealer 9 give +2 while the hole remains hidden. Revealing an Ace changes that same running count to +1. The concealed card is never counted early.

The lessons call the existing `hi_lo` helpers; they do not maintain a second counting convention. The estimate is `max(0.5, ceil((decks − exposed_cards / 52) / 0.5) × 0.5)`. It deliberately counts only known public faces, rather than looking at the exact shoe cursor. Fixed lesson cards are teaching examples, not normal gameplay or a hidden test shoe.

## Compact deviation profile

**ID:** `hi_lo_i18_s17_6d_positive_stands_v1`.

The profile uses four positive hit/stand indices from Don Schlesinger's canonical **Illustrious 18**, as published with permission by Michael Shackleford's [Wizard of Odds Hi-Lo article](https://wizardofodds.com/games/blackjack/card-counting/high-low/). [BlackjackInfo's published six-deck S17 chart](https://www.blackjackinfo.com/card-counting/illustrious-18/) independently gives the same four values and the at-or-above comparison. Sources were read on 2026-10-02. This is one internally consistent subset, rather than a mixture of different publishers' charts.

| Original hard two-card hand | Dealer upcard | Basic strategy | At or above integer TC | Count-adjusted play |
| --- | --- | --- | --- | --- |
| 15 | Ten-valued | Hit | +4 | Stand |
| 12 | 3 | Hit | +2 | Stand |
| 12 | 2 | Hit | +3 | Stand |
| 16 | 9 | Hit | +5 | Stand |

`src/training/deviations.lua` enables the profile only for validated six-deck S17 rules with any-two doubling and DAS. The shared validator also guarantees this project's 3:2 natural payout, US hole card and peek, and disabled surrender/insurance. All three penetration settings are allowed. The lookup covers only original, unsplit, non-pair, hard two-card decisions whose independently supplied basic recommendation is Hit and whose shared legal-action set allows both Hit and Stand.

Pairs, split hands, soft hands, three-card hands, double/split/insurance/surrender deviations, zero indices and negative indices are deliberately omitted. Eight decks, H17, restricted doubles, no DAS and future unsupported rules return an unavailable reason. They keep basic strategy; no nearby profile is silently substituted. The count passed to lookup must agree with the locked exposed-card estimate and truncation. No hole-card rank or future card is read.

**Estimator limit:** published indices are applied as an educational policy using the owner's locked estimate. The source's simulation uses nearest-half-deck estimation; this game rounds exposed-card estimates upward. Its simulation profits, advantage figures and performance claims therefore do not transfer to this game. The four positive integer comparisons avoid the different negative behavior of floor versus truncation, but that does not establish expected-value optimality under this game's estimator or every hand composition. No fresh EV solver or risk-adjusted index generation is claimed.

The interface distinguishes Basic Strategy from count-adjusted play. Below the index it retains Hit; at the index it can explain that this profile now chooses Stand. Neither choice guarantees the next outcome. The profile recommends actions, never a betting progression or real-money play.

## Verification and asset rights

`tests/deviations.lua` checks below, exact and above each threshold, all 72 rules configurations, omitted hands, stale counts, hidden-card independence, action legality and non-mutation. `tests/tutorial.lua` checks ten explicit answers, minimum-deck and signed-truncation examples, hidden-hole practice, progression, feedback and deterministic replay. Tests use independently written expected numbers.

All code, lesson wording and UI explanations are written for Royal Pocket Casino. Only the documented numerical facts are encoded; no publisher's chart image, PDF, JavaScript, logo or explanatory prose is imported into the package. Source citations are provenance, not a professional audit or a claim that publisher permission has been granted to reuse their chart assets.
