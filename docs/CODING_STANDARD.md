# CODING_STANDARD

**Status:** proposed engineering policy, pending owner approval of the foundation.

## Primary rule

**Never refactor working readable code merely to make it appear more sophisticated. Prefer the simplest implementation that correctly satisfies the specification and remains understandable to a junior developer.**

Optimize for understanding, debugging, correctness and maintenance. AI-generated code follows the same standards as human code. The repository must explain itself without access to a chat history.

## Modules and functions

- One clear responsibility per module, using the ownership table in ARCHITECTURE.
- Use plain tables and focused functions for the Lua core. Add a class/pattern only when a current requirement makes it clearer.
- Prefer explicit branches, named intermediate values and early validation to clever one-liners, chained expressions or compact boolean tricks.
- Use descriptive `snake_case` module/function/variable names. Examples: `stake_units`, `dealer_upcard`, `is_split_hand`, `evaluate_hand`, `calculate_return_units`.
- Give amounts explicit units and rates explicit numerator/denominator names. Avoid ambiguous names such as `amount`, `total`, `money`, `data`, or `result` when several meanings coexist.
- State ownership and return contracts. Callers must not mutate the live domain state. Avoid shared mutable globals and implicit cross-module initialization.
- Keep main.lua responsible only for construction and framework callbacks. It must not contain Blackjack decisions, save decoding, widgets and payouts together.
- Treat functions over roughly 40 lines or modules over roughly 250 lines as a review prompt, not an enforced line limit. Split only at a meaningful responsibility boundary; do not scatter a readable rule among dozens of tiny helpers.
- Prefer one small dedicated helper over duplicate payout/validation logic. Do not create generic utility collections for hypothetical reuse.
- Remove unused code/dependencies and obsolete branches. No placeholder future games, empty services, TODO-only modules or generated filler.

## Lua portability and errors

Use Lua 5.1-compatible syntax in shared code. Avoid FFI/native modules, Lua-version-specific operators, OS APIs, wall-clock reads and LÖVE calls in the domain. Keep dynamic typing understandable through validated inputs, explicit field names and a few useful annotations; do not build an elaborate home-grown type system.

Use ordered arrays for cards/hands/commands and stable explicit iteration. Do not let `pairs` traversal decide gameplay or deterministic serialization. Treat optional fields and empty arrays consistently in save encoding.

Invalid player commands return readable reasons and unchanged state. Save/input failures are expected errors with explicit handling. Assertions are appropriate for programmer invariants/tests, not a replacement for corrupted-save recovery. Never catch every error and silently reset bankroll or continue with fabricated cards.

Choose formatter settings once and use them consistently. A formatting-only change should be separate from a behavior change where practical. Pin development tool versions after compatibility validation.

## Comments and educational module documentation

Use section comments at important conceptual boundaries, for example `-- ## BLACKJACK PAYOUTS` or `-- ## SAVE PLAYER PROGRESS`. JavaScript adapter files use `// ## ...`; Python test/report helpers use `# ## ...`. Do not add section dividers to every three-line helper.

Comments explain why, non-obvious game rules, important constraints or architectural decisions. Ordinary code explains what. “Increase count” beside an increment is noise. A comment explaining why split Ace+10 is ordinary 21 is useful.

Important modules start with concise PURPOSE / CHANGE THIS MODULE WHEN / DO NOT PUT HERE notes. For `shoe`, explain that it owns remaining/discarded cards, shuffle and penetration; changes to those belong there; payouts, rendering and controls do not. Usually 6–12 lines are enough. Keep the module ownership table in ARCHITECTURE current; do not create one Markdown file for every module.

Explain an issue before its fix during mentoring/review: describe the failing Blackjack example, the relevant rule, and then the smallest change. For a learning exercise, invite the owner to predict a fixture's outcome or implement a small isolated helper, without withholding authorized work or delaying required checks.

## Test readability

Name tests as scenarios: “split ace and king pays an ordinary win,” “dealer soft 17 draws under H17,” or “save recovery keeps bankroll and statistics from the same revision.” Use named cards/bets/rules in fixtures and Given/When/Then organization where useful.

Expected results must be independently reasoned from BLACKJACK_RULES. Do not calculate expected payouts using the production payout helper under test. Prefer small concrete scenarios to snapshots of enormous internal tables. Make regression fixtures narrow enough to show the original bug.

## Git and review discipline

Initialize Git and choose a GitHub repository only in the approved implementation phase. Use short feature branches for meaningful changes and small coherent commits. Do not commit unrelated formatting, asset imports, behavior changes and dependency upgrades together.

Good commit: `Add deterministic split-hand settlement tests`. Bad commit: `updates`. Commit bodies explain non-obvious tradeoffs. Version tags identify tested release commits; release notes distinguish behavior, limitations and verification evidence. Maintain a concise CHANGELOG when implementation begins.

Pull requests describe the problem, resulting behavior, changed rules/save semantics, and actual validation. Link the applicable spec and tests. Preserve secrets/signing keys outside source control. Add ignore rules before generating builds, logs, local saves or debug bundles.

## AI-assisted change policy

The approved cycle is specification → implementation → tests → independent review → fixes → tests again → human review → merge. AI is an accelerator, not the authority over rules or evidence.

Before coding, read the relevant specification and local instructions. If a rule is unanswered or contradictory, make the uncertainty concrete and resolve it; never guess and hide the choice in code. Do not broaden scope to justify an elegant abstraction.

Important changes include payouts, legal actions, RNG/shoe behavior, rule profiles, persistence/migrations, statistics, dependency/runtime updates and release packaging. They require review independent of the author. A separate AI reviewer may assist, but does not constitute a qualified audit or replace owner review. For a solo owner, review one's own implementation is still useful but does not satisfy the independent-review claim; record the gap and obtain a second reviewer before releasing an important change.

Reviewers inspect specifications, concrete scenarios and code, and can rerun checks. Self-reported success from the writing AI is insufficient. Fixing review findings requires relevant checks again. Keep decisions and explanations in specs/PRs/code, not only in chat.

Do not install dependencies, run compatibility experiments, create production code, build packages, publish, or add cloud/monetization components during this architecture-only task. Later changes must remain within the owner's approved milestone.
