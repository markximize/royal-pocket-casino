# DEFINITION_OF_DONE

**Status:** reusable proposed checklist. Apply relevant items; document why an item is not applicable. “Not tested” is not “not applicable.”

The authorized desktop preview is available for owner evaluation. Its local automated checks and desktop smoke tests do **not** mark this release checklist complete: owner playtesting, RG35XX H budgets/acceptance, hosted CI and public-release licensing remain outstanding. Local static lint and separate AI review have run; AI review is not human approval or a professional audit. See [DESKTOP_PREVIEW](DESKTOP_PREVIEW.md) for concrete evidence.

The owner reports successful physical play of the earlier preview.3. The explicitly authorized preview.4 polish adds learning/coaching and format-3 migration; its own physical QA remains pending. See [HANDHELD_TEST](HANDHELD_TEST.md) and the [final polish record](../artifacts/polish-evidence/FINAL_VERIFICATION.md). Preparing the ZIP completes the packaging task, not the unchecked device, rights, hosted-CI or human-release gates below.

## Feature or bug fix

- [ ] Approved scope and specification are satisfied; unanswered rule/product decisions are resolved before implementation.
- [ ] Behavior is explained with a concrete example and agrees with BLACKJACK_RULES.
- [ ] Modules/functions are readable, responsibilities clear, names/units descriptive, and unused/duplicate code removed.
- [ ] No speculative framework, future feature, real-money mechanic, mandatory account or network dependency was introduced.
- [ ] Relevant unit/scenario/integration tests exist and pass; important expected outcomes were independently checked.
- [ ] A bug fix has a focused regression test that fails on the prior implementation, or a recorded manual regression scenario for a purely visual issue.
- [ ] Relevant edge cases and unsupported/invalid actions/configurations are handled explicitly.
- [ ] Existing required tests, formatting, static lint and dependency-boundary checks pass on the final code.
- [ ] RNG/replay and integer arithmetic contracts remain valid where affected.
- [ ] Bankroll, save/recovery/migration and statistics interactions are verified where affected; no partial or duplicate settlement.
- [ ] UI/readability/focus and reduced-motion/audio behavior are verified where affected.
- [ ] Controller behavior is tested on the nominated RG35XX H where relevant; a desktop keypress is insufficient evidence.
- [ ] Performance/storage budgets are checked where affected, with actual results and limitations recorded.
- [ ] Important module documentation and affected specs are updated; no decisions exist only in chat.
- [ ] Dependency/asset provenance, permissions, license compatibility and notices are complete for new imports.
- [ ] Independent review of important logic/save/runtime changes is complete; findings are fixed and checks rerun.
- [ ] Owner/human review is complete; the owner can explain the change's inputs, output and main rule.
- [ ] Change is a small coherent commit/PR with meaningful description and actual validation evidence.

## Release candidate

- [ ] Approved milestone scope is complete, with explicit deferred features.
- [ ] Full required domain/integration suite and declared long simulation validation passed; anomalies and limitations are addressed.
- [ ] Artifact is reproducible from a recorded commit/toolchain and contains only intended assets/code/runtime files.
- [ ] Final artifact's checksum identifies the exact package reviewed and tested.
- [ ] Real RG35XX H/muOS tests cover installation, complete play including splits/doubles, controller navigation, audio, readability, exit/relaunch, resume, save failure and update preservation.
- [ ] Startup, frame pacing, memory, save timings and package/runtime sizes meet approved budgets or have explicit owner-approved exceptions.
- [ ] Each additionally claimed platform has its own real runtime/device/browser evidence; build, signature, installation and launch are separate claims.
- [ ] License decision, third-party notices, asset permissions, attribution and branding/build permissions are resolved.
- [ ] Installation/update/backup/rollback instructions, changelog, release notes, limitations, checksums and version tag are present.
- [ ] Signing keys/release secrets are protected and absent from source/history/artifacts.
- [ ] Independent review and owner review cover the final behavior; fixes received fresh relevant tests.
- [ ] Quality statements match recorded evidence; no manufactured audit/certification claims.

## Architecture-only completion

For this task, done means the seven specification documents and their index are coherent, decisions are visibly pending, platform evidence/assumptions are distinguished, the roadmap/gates are explicit, and **no game or proof-of-concept implementation has begun**. Implementation and release checklist boxes remain unchecked until there is evidence.
