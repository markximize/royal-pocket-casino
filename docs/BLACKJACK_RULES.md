# BLACKJACK_RULES

**Status:** approved for the desktop prototype on 2026-10-01; final release review pending. **Rules specification revision:** 1 (semantics unchanged).

This document is the single source of truth for prototype gameplay, settlement and scenario tests. Future Basic Strategy Trainer rules must match it. The table describes this product's rules, not all Blackjack tables. A strategy table remains separately verified data; correct gameplay rules alone do not generate correct strategy advice.

## Proposed preset and bounded configuration

Approved prototype preset ID: `royal_classic_v1`. The owner accepted the proposed defaults and bounded variants, including disabled variants, for the desktop prototype. “Fixed” means fixed for this rules revision, not fixed forever. An identified future variant must be rejected rather than partially supported.

| Rule | Proposed preset | V0.1 configurable values | Deferred decision/variant |
| --- | --- | --- | --- |
| Seats | One local player, one initial hand | Fixed | Multiple seats/AI opponents |
| Decks | 6 standard decks, no jokers | 6 or 8 | 1/2/4 decks need new profile/tests |
| Card values | Ace 1 or 11; 2–9 face value; 10/J/Q/K = 10 | Fixed | Nonstandard decks excluded |
| Natural Blackjack | Original unsplit two-card Ace + ten-valued card only | Fixed | Split 21 as natural excluded |
| Blackjack payout | 3:2 profit, plus returned stake | Fixed | 6:5 can be represented exactly but is not supported gameplay in V0.1 |
| Ordinary win / push | 1:1 profit / stake returned | Fixed | Push loses, five-card Charlie, bonuses excluded |
| Dealer soft 17 | Stand (S17) | Stand or hit (H17) | None |
| Other dealer totals | Hit below 17; stand on hard 17–21; bust above 21 | Fixed | Dealer discretion excluded |
| Double totals | Any legal first two cards | Any two, 9–11, or 10–11, using best non-bust total, including soft totals if eligible | Hard-only double is a distinct future variant |
| Double mechanics | Additional stake exactly equal to current hand stake; one card then finish | Fixed | Double for less/redouble excluded |
| Double after split | Allowed on eligible non-ace split hands | On or off | Split-ace double excluded |
| Split eligibility | Exactly two cards of the same rank | Fixed | Equal value (e.g. K+Q) excluded |
| Max split hands | Four total player hands, not four split operations | Fixed | Other caps require explicit tests |
| Resplit non-aces | Allowed while under four-hand cap | Fixed | No-resplit variant deferred |
| Split aces | Allowed; one additional card on each ace, then finish | Fixed | Hitting split aces deferred |
| Resplit aces | Not allowed | Fixed | Resplit-ace variant deferred |
| Ace+ten after split | Ordinary 21, no natural payout | Fixed | None |
| Split timing | Only on a current two-card hand before Hit/Double/Stand | Fixed | Splitting after extra cards excluded |
| Surrender | Disabled | Fixed | Late/early, vs Ace/10, after split, and interaction with no-peek each need separate rules |
| Insurance | Disabled | Fixed | If added: Ace upcard only, original bet/2, 2:1 profit, separate side wager before peek |
| Even money | Disabled | Fixed | If added: only original natural vs Ace, 3:2 rules, guaranteed 1:1 profit; no duplicate insurance settlement |
| Hole card | US hole-card model | Fixed | European no-hole-card, hole/no-peek, deferred peek excluded |
| Peek | Dealer checks on Ace or ten-valued upcard before player actions | Fixed | No-peek loss exposure needs its own rule |
| Dealer natural | Ends round before split/double; player natural pushes, other initial hands lose | Fixed | ENHC loss-all / original-bets-only / original-and-busted policies deferred |
| Player total 21 | Automatically finishes the hand; no further Hit/Double | Fixed | None |
| Table bets | 5–100 chips inclusive, steps of 5 whole chips | Fixed, pending OD-04 | Fractional bets and variable denominations deferred |
| Funding actions | Split/Double require enough available bankroll for full additional stake | Fixed | Credit/negative bankroll excluded |
| Penetration | 75% of shoe dealt; finish that round, then shuffle | 50%, 67%, or 75%, stored as integer percent | Random cut location deferred |
| Shuffle | Full replacement shoe, Fisher–Yates using injected unbiased bounded draws; between rounds | Fixed | Continuous shuffle/every-round shuffle excluded |
| Burn cards | None | Fixed | Hidden/exposed burns require count/penetration rules |
| Manual shuffle | Available between rounds, never during a live round | Fixed | Record as shoe reset for count continuity |
| Deck/rule change | Between rounds only; start a fresh shoe, record new rule profile | Fixed | No retroactive settlement changes |
| Exhaustion | No mid-round reshuffle; void/refund entire interrupted round, mark void, force fresh shoe before next bet | Fixed, pending OD-09 | Different reserve/exhaustion policy needs approval |
| Bust precedence | Player bust loses even if dealer later busts | Fixed | None |
| Dealer draw optimization | Do not draw when all player outcomes are already determined | Fixed | Reveal hole at round end; never invent undealt cards for counts |
| Extra bets/modes | No side bets, progressive jackpots, multiple action bets, autoplay, or rule scripting | Fixed | Separate scope decision |

The supported matrix has 72 combinations (2 deck choices × 2 soft-17 choices × 3 double choices × 2 DAS choices × 3 penetration choices). A configuration validator checks enums, cross-field restrictions, table bet divisibility, and the complete schema. It must reject unknown rule fields/values, unsupported payouts, impossible combinations, and attempts to change live-round rules. No silent fallback.

## Cards and hand evaluation

Each physical card has a unique shoe-local ID, deck index, suit, and rank. Rank and numeric value are separate: K and Q both count 10 but cannot split under the proposed same-rank rule. Two decks may legitimately contain the same rank/suit; they must still have distinct IDs.

Evaluate a hand by counting all aces as 1, then upgrading one ace by 10 if the total remains at or below 21. A hand is soft only when an ace is currently counted as 11. Natural status also checks original two-card, unsplit origin; total 21 alone is insufficient.

| Hand | Total | Soft? | Natural? |
| --- | --- | --- | --- |
| A+K, original | 21 | Yes | Yes |
| A+K, split origin | 21 | Yes | No |
| A+6 | 17 | Yes | No |
| A+6+10 | 17 | No | No |
| A+A+5 | 17 | Yes | No |
| A+A+9 | 21 | Yes | No |
| A+A+9+K | 21 | No | No |
| K+Q+2 | 22 | No | No |

## Round flow and exposure

1. At the betting boundary, validate settings, apply any pending shuffle, and validate the bet against table and bankroll limits. Debit the original stake exactly once.
2. Deal in fixed order: player first card, dealer upcard, player second card, dealer hole card. All four leave the shoe; only the first three are exposed initially.
3. If insurance/even money is ever supported, present that decision on an Ace upcard before the peek. Neither is available in the proposed V0.1 preset.
4. On an Ace or ten-valued upcard, peek before any player Hit/Split/Double/Surrender. A failed peek reveals only “no dealer Blackjack,” not the hole-card rank.
5. Dealer natural ends the round. Otherwise settle any original player natural without extra dealer draws; an upcard 2–9 cannot form a dealer natural.
6. Play the current player hand. Split hands are processed left to right as defined below. Legal actions come from domain state and current approved rules.
7. After player hands finish, reveal the dealer hole card exactly once. Draw for the dealer only if at least one ordinary non-busted hand needs comparison. S17/H17 controls soft 17. Never draw for cosmetic reasons.
8. Resolve all hand outcomes, side wagers if supported, statistics, and bankroll in one round-completion transaction. Present a result summary before the next bet.
9. Move all drawn round cards to the discard partition. If penetration was reached, exhaustion occurred, or settings require a new shoe, shuffle before the next round.

Invariants: only one current player hand; no decision after settlement; no bet change after deal; no duplicate debit/credit; no card dealt twice; rules immutable within a round; unavailable actions leave state unchanged.

## Player actions

- **Hit:** draw one card to current hand. Bust ends it; 21 also ends it. Otherwise the player may choose again.
- **Stand:** finish current hand without drawing. Advance to the next unfinished hand or dealer resolution.
- **Double:** require two cards, eligible total, approved DAS rule and sufficient funds. Debit one equal stake, double the hand stake, draw one card, then finish even if the total is below 17. A natural/21 or locked split-ace hand cannot double.
- **Split:** require matching rank, two cards, funding and hand capacity. The existing stake stays with the first new hand; debit an equal stake for the second. Create two hands with one original card each and split-origin metadata. Insert the second directly after the first. Draw a replacement card for the first, play that hand to completion (including permitted resplits), then draw/play the next pending hand. Do not predeal replacement cards for every hand.
- **Split aces:** special case: draw one additional card to the first ace, finish it, then do the same to the second. A replacement Ace does not reopen the hand because resplitting aces is disabled. Each outcome is an ordinary hand, including A+10.

Table maximum applies to the **original opening bet**, not total round exposure. A 100-chip opening bet can produce four 100-chip hands, each doubled to 200 if rules and bankroll allow; total exposure can reach 800 chips. Funds are checked per action; there is no automatic all-in split/double for less. The UI must show the extra required amount.

## Exact settlement contract

Stake is removed from available bankroll when committed. Settlement returns include the original stake; “profit” excludes it. See ARCHITECTURE for bounded integer storage.

| Outcome | Return credited for stake B | Net result |
| --- | --- | --- |
| Player bust / ordinary loss | 0 | −B |
| Ordinary win / dealer bust | 2B | +B |
| Push | B | 0 |
| Natural win at 3:2 | B + 3B/2 | +3B/2 |
| Both original naturals | B | 0 |
| Split 21 beating ordinary dealer 20 | 2B | +B |
| Split 21 vs ordinary dealer 21 | B | 0 |

Compare in this order: dealer natural special resolution; player original natural; player bust; dealer bust; ordinary totals. A natural beats an ordinary three-card 21. Do not award the natural premium to split hands or doubled hands. Player and dealer bust is a player loss.

Examples for an opening bankroll of 1,000 chips and a 10-chip initial bet:

| Scenario | Debits | Credits | Ending bankroll |
| --- | --- | --- | --- |
| A+K vs dealer 10+9 | 10 | 25 | 1,015 |
| A+K vs dealer A+Q | 10 | 10 | 1,000 |
| Player 22, dealer subsequently 23 | 10 | 0 | 990; dealer need not actually draw if no hand needs it |
| Double, final 20 beats 19 | 20 total | 40 | 1,020 |
| Split, first hand wins and second loses | 20 total | 20 | 1,000 |
| Split, first doubles and wins, second pushes | 30 total | 40 + 10 | 1,020 |

No rounding is permitted. Validate payout divisibility before accepting a betting/rule configuration. A retry or save resume cannot settle the same round twice.

## Disabled variants: specification before enabling

These definitions explain the decisions that would be required; they do not authorize implementation.

- **Insurance:** only against an Ace upcard, on the original unsplit bet. Proposed exact stake B/2, purchased only when funded, before peek. Dealer natural returns three times the insurance stake (stake plus 2:1 profit); otherwise returns zero. The main wager settles independently. Decide whether smaller insurance bets are permitted; default proposal is full half only.
- **Even money:** for an original natural against an Ace, a guaranteed +B result under a 3:2 ruleset, offered before peek. Decide UI choice/exclusivity with insurance. Never both credit even money and settle another premium/insurance payment. Do not carry this shortcut unchanged into a 6:5 variant.
- **Late surrender:** proposed first two cards on an unsplit, non-natural hand after dealer natural is ruled out; return B/2. Decide permission against Ace/10 and soft/hard totals, and explicitly forbid or specify surrender after split.
- **Early surrender:** before dealer natural is ruled out. Its allowed upcards, insurance interaction, and precedence require a separate specification and strategy profile.
- **No-hole-card / no-peek:** decide when the second dealer card is dealt or checked and which split/double/busted wagers lose to a subsequent dealer natural. “Original bets only” cannot be approximated by the US-peek settlement path.
- **Split variations:** equal-valued faces, caps, resplit aces, hitting/doubling aces, and a natural premium after split each affect legal actions and/or strategy. Add them independently with fixtures.

## Shoe contract

Build exactly 52 × deck_count distinct physical cards. Shuffle with Fisher–Yates: at each descending position choose a uniformly distributed integer from the remaining prefix, using the injected generator. Do not use a random comparator sort or biased modulo conversion.

Cut position = floor(total_cards × penetration_percent / 100). All drawn cards, including the hidden hole card, count toward penetration; no burn cards exist in this preset. Crossing the cut marks “shuffle before next round”; never rebuild the shoe during the current round.

Unexpected exhaustion voids the whole round: restore the bankroll to its round-opening amount, reverse that round's debits/credits including any side-wager result, commit only a void-round statistic, and mark a forced new shoe. Earlier valid round statistics remain. Explain the interruption visibly. Do not leave some split hands paid and others cancelled. Predetermined scenario shoes may be short by design; exhaustion must produce the same explicit failure path, never fall back to random cards.

A production saved shoe is validated for exact card membership and all partitions: undrawn, current round, and discarded. Scenario tests may use a separate explicitly labeled partial-shoe fixture; partial production saves are invalid.

## Trainer contract

Basic Strategy Trainer consumes this configuration and the engine's legal-action set. A verified strategy profile must match every strategy-relevant field (decks, S17/H17, double permissions, DAS, split/ace restrictions, surrender and peek model). Penetration belongs to count exercises but does not imply a different total-dependent basic-strategy table. Unsupported profiles return a visible unavailable result, not guessed advice.

Future Hi-Lo card tags: 2–6 = +1; 7–9 = 0; 10/J/Q/K/A = −1. Count only actual exposed cards, each physical ID once; a hidden hole contributes nothing until revealed. A shuffle resets count. True-count divisor/rounding, deck estimation, full-shoe versus individual drills, and count-display pedagogy need OD-08 detail before trainer implementation. A trainer must not read the hidden shoe to supply advice presented as visible-card knowledge.

## Reference context

Published table rules demonstrate why insurance, surrender, split aces, and peek timing must be explicit. The product's approved document governs its behavior; it does not claim compliance with a real-money casino rulebook. See the [New Jersey Division of Gaming Enforcement rules of games, Chapter 69F](https://www.nj.gov/oag/ge/docs/Regulations/CHAPTER69F.pdf), Blackjack subchapter, for examples of separately specified options.

## Approval record

Owner approval: **DESKTOP PROTOTYPE APPROVED, 2026-10-01**. The owner selected “First playable desktop Blackjack build using the proposed defaults” after being told this approves proposed V0.1 Blackjack rules and chip defaults for the prototype. The preset, supported matrix, disabled variants, dealing order, settlement examples, penetration/exhaustion and economy references above are unchanged from that proposal. Hardware support, public-release licensing and final release review remain pending. Change the preset ID/revision when approved semantics change; preserve old saved-round interpretation through a migration or explicit compatible rules handler.
