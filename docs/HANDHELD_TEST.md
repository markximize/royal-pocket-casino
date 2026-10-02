# RG35XX H — V0.1 polish test candidate

**Candidate:** 0.1.0-preview.4, save format 3, engine 1. **This candidate's hardware approval: pending.** The owner reports that a previous build ran successfully on the RG35XX H. That report is useful prior evidence; it does not verify this new package, its updated controls/audio, or measured performance. This remains a private Blackjack/learning test candidate, not a public release.

## Package and requirements

Use **artifacts/royal-pocket-casino-v0.1-polish-rg35xx-h-test.zip** and its sibling `.sha256` file. The desktop sibling is **artifacts/royal-pocket-casino-v0.1-polish-test.love**. The handheld ZIP uses this installation layout:

```text
ROMS/Ports/Royal Pocket Casino.sh
ports/royalpocketcasino/
  game.love
  INSTALL_AND_TEST.md
  TRAINING_RULES.md
  LEARNING_GUIDE.md
  SESSION_COACH.md
  AUDIO_AND_BRANDING.md
  THIRD_PARTY_NOTICES.md
  notices/
```

The logo and original sound recipes are inside `game.love`; no separate image/audio upload is needed. The package contains no runtime, firmware, existing saves, Windows binaries or generated dependencies. It uses your existing PortMaster installation, aarch64 controller/graphics libraries, and its `runtimes/love_11.5/love.txt` helper plus actual LÖVE executable/libraries. Runtime acquisition is an installation step; the installed game then needs no connection. Public source/asset licensing and the exact handheld runtime's notices still need review.

**OWNER-REPORTED:** RG35XX H, muOS 2508.4 Loose Goose, kernel 4.9.170 aarch64, and successful operation of an earlier build. **PREVIOUSLY OBSERVED:** the PC reached the MustardOS/SFTPGo login and SD1 listing over Wi-Fi. **DOCUMENTED:** muOS SFTP+Filebrowser uses port 9090; documented default credentials are muos/muos. **MUST BE VERIFIED FOR PREVIEW.4:** exact runtime/helper identity, package launch, graphics fit, physical mappings, audible playback, save migration/restart, exit, pacing/memory and stability. Earlier difficulty locating LÖVE in the runtime menu is historical; if this package fails its runtime checks, use the actual new log rather than assuming the earlier installation remains identical.

## Wi-Fi installation — no cable or card reader

1. Keep the PC and handheld on the same Wi-Fi. On muOS, enable **SFTP + Filebrowser** under Configuration → Webservices (some menus place this under Connectivity).
2. Open your device's address, currently **http://192.168.8.136:9090**, on the PC. It can change after reconnection. Sign in using your configured credentials; the documented defaults are **muos / muos**.
3. On the PC, extract the ZIP into a temporary folder. Do not upload just the ZIP and expect the handheld to run it automatically.
4. Open **SD1 (mmc) → ROMS → Ports**. Create `Ports` inside the existing `ROMS` folder if needed. Upload the ZIP's `ROMS/Ports/Royal Pocket Casino.sh` here. This is the menu launcher, at `/mnt/mmc/ROMS/Ports/Royal Pocket Casino.sh`.
5. Return to **SD1 (mmc) → ports** at the card root. Create `royalpocketcasino` there only if absent. Enter it and upload `game.love` and the supplied Markdown records from the ZIP's `ports/royalpocketcasino`. Create its `notices` folder if absent and upload the supplied notice files. This puts the game at `/mnt/mmc/ports/royalpocketcasino/game.love`. The root `ports` folder is distinct from `ROMS/Ports`.
6. Check both destinations below. Before updating an existing build, close the game and copy its entire `data/` folder and any `portmaster-path.txt` override to the PC. Upload the supplied program files individually over their prior versions; **never replace/delete `data/`, overwrite `portmaster-path.txt`, or replace the whole game directory**. The package does not supply either of those user-owned items. Keep the previous launcher log if diagnosing an issue. A browser folder upload may preserve a supplied tree, but do not assume it preserves unrelated files or permissions. Avoid extra `ports/ports` or `ROMS/Ports/ROMS` nesting.
7. On the handheld, use **Explore Content** to open that Ports folder and select **Royal Pocket Casino**. If muOS asks for a core, assign the same Ports/PortMaster shell launcher used by an existing working port. The exact menu/core label must be confirmed on your installed firmware.
8. A successful launch should show the supplied Royal Pocket Casino logo and eight entries, including **Learn Hi-Lo**. Settings also exposes Assisted Play, Session Coach and About/Credits. Run the checklist below. Exit through Settings → Exit, then launch again to check persistence. On an existing profile, confirm the old bankroll/hand before making the first new-format save.

Sources: [muOS Filebrowser instructions](https://muos.dev/web/sftpfilebrowser), [muOS webservices](https://muos.dev/tour/modules/muxwebserv), [PortMaster porting guide](https://portmaster.games/porting.html). The steps after transfer remain a proposed device procedure until executed on this exact package.

### Exact SD1 destinations

| Item | Filebrowser destination | Linux location |
| --- | --- | --- |
| Launcher | SD1 (mmc) → ROMS → Ports | `/mnt/mmc/ROMS/Ports/Royal Pocket Casino.sh` |
| Game/data folder | SD1 (mmc) → ports → royalpocketcasino | `/mnt/mmc/ports/royalpocketcasino/` |
| Game archive | Inside that folder | `/mnt/mmc/ports/royalpocketcasino/game.love` |
| Launch/runtime log | Inside logs after launch | `/mnt/mmc/ports/royalpocketcasino/logs/launcher.log` |
| Save backup root | Inside data after launch | `/mnt/mmc/ports/royalpocketcasino/data/` |
| Optional local path override | Inside the game folder | `/mnt/mmc/ports/royalpocketcasino/portmaster-path.txt` |
| PortMaster prerequisite | SD1 (mmc) → MUOS → PortMaster | `/mnt/mmc/MUOS/PortMaster/` |

This SD1-only candidate follows [muOS's documented split layout](https://muos.dev/installation/portmaster): launchers under ROMS/Ports and game data under the root ports folder. The prior session showed root `ROMS`, `ports` and `MUOS/PortMaster`; existence of `ROMS/Ports`, `control.txt` and the LÖVE helper still needs confirmation. No SD2 search or system changes are part of this package. Linux LÖVE normally places saves under `data/love/royal-pocket-casino-desktop-preview`; the **Save directory** line in `launcher.log` is authoritative for the actual runtime.

## If it returns to muOS or does not launch

Use the PC browser to open **SD1 (mmc) → ports → royalpocketcasino → logs → launcher.log**. Copy the failure text. The launcher checks prerequisites and does not modify firmware or fetch random libraries. If the whole game folder is missing, its error occurs before log creation: verify `/mnt/mmc/ports/royalpocketcasino` first.

- **Missing love_11.5/love.txt:** do not copy Windows LÖVE files onto the handheld. Check the installed PortMaster version/runtimes through its normal interface. If LÖVE is absent from that interface, stop and report the log; we must validate a supported runtime route instead of assuming a path or forcing system changes.
- **Missing/ambiguous control.txt:** inspect the real PortMaster directory. The launcher checks documented candidates. Put the confirmed absolute directory containing `control.txt` on one line in `royalpocketcasino/portmaster-path.txt`; do not guess it. This changes only this game's lookup.
- **Missing executable/libraries, wrong ABI or graphics failure:** retain the log, runtime version and muOS version. Report the exact error before attempting a workaround. No firmware replacement is part of this test.
- **No controller actions:** report controller name/GUID and `gamepad=` from the log. SDL names are provisional bindings; a physical A-label mismatch needs measured mapping, not random remapping.
- **Save failure:** keep the prior files, use Retry, and record the error. Do not reset the profile. A different valid migration backup must be copied aside safely before retry; its bytes are deliberately protected.

The launcher creates only owned `logs/` and `data/` folders, sets XDG data for this game, and stops only its own exit-helper process. It avoids global kill commands and service restarts. Save files are under the runtime-reported directory inside `royalpocketcasino/data/`; the desktop identity name is retained for compatibility. Copy that whole folder while the game is closed for backup.

## Physical-device record

Record the new package SHA-256, muOS version, PortMaster version/runtime, SD card, cold/warm launch time, controller name/mapping and observed issues. Keep this record separate from the owner's earlier successful-build report. Blank means not tested.

| Check | PASS / FAIL | Notes |
| --- | --- | --- |
| Boot; supplied logo/eight-entry menu; 640×480 and readable text/cards | | |
| D-pad focus; A confirms; B returns | | |
| X/Y count ±1; L/R count ±5; Start returns/opens menu | | |
| Blackjack: Hit, Stand, Double, split hands/aces, natural, bust, push | | |
| Card reveal/dealer pacing; reduced motion; no unexpected input repeats | | |
| Audio: paper deal/flip; distinct chip up/down; quiet navigation; positive payout | | |
| Audio: win/natural Blackjack/bust/loss/push cues; mute mid-cue; volume 0/normal | | |
| Learn Hi-Lo: five stages; positive/negative entry; X/Y ±1; L/R ±5; Submit/Next/Back | | |
| Tutorial: half-deck steps; negative TC truncation; hole hidden then revealed once | | |
| Tutorial completion opens practice; leaving/restarting lessons preserves normal hand/chips | | |
| Strategy: correct/incorrect explanation, legal buttons, current rules | | |
| Beginner/practice/advanced counting; tenth card visible before checkpoint | | |
| Running/true count entry; negative counts; no hidden-hole count | | |
| Optional RC/TC/deck HUD independently toggles; normal play unaffected | | |
| Assisted Play OFF/BASIC/ADVANCED; hints/explanations/count/deviations switch separately | | |
| Deviation prompts OFF: advice and coach both use basic strategy; displays can stay OFF with checkpoints ON | | |
| Assistance waits for card reveals; menu/home pauses unseen cards; no hole-card disclosure | | |
| Supported six-deck S17 deviations labeled separately; unsupported profiles explain fallback | | |
| Coach: empty/insufficient evidence is honest; results and decision accuracy stay separate | | |
| Coach: Practice this opens the selected category; correct Double drills improve its score | | |
| Coach: New session only between rounds; history and current session survive restart | | |
| Coach/credits pages: focus buttons and L/R paging; logo/copyright/version/notices readable | | |
| Gameplay and trainer statistics stay separate; streaks/accuracy | | |
| Existing v1/v2 profile: bankroll/hand/shoe/preferences retained; first save preserves exact old-format backup | | |
| Save, exit, restart: same normal hand/bankroll, trainer totals, assistance and coach/history | | |
| Completed round: prior wager retained, Deal focused; resume/restart retains prior actual wager while affordable | | |
| Exit to muOS; second launch; no stuck audio/mapper process | | |
| 10–15 minutes across all modes: no crash, lag, heat issue or clipping | | |
| Wi-Fi disabled after installation: play, trainers, lessons and coach all work | | |

Use actual visible scenarios; do not mark a rare push/split tested without encountering it. The separate desktop deterministic tests cover those semantics, but physical navigation/renderer behavior still needs device evidence. Select is not assigned an essential V0.1 action; report any firmware exit-chord behavior separately.

For migration, close and back up the existing save directory first. After launch, compare bankroll, current player/dealer display and normal statistics with the previous build. After the first accepted preference/gameplay change, confirm `backup_format_1.json` or `backup_format_2.json` exists in the runtime-reported save directory, then exit/relaunch and compare again. Do not delete, edit, corrupt or replace a personal save to test error handling; deterministic tests cover corruption and retry scenarios. If an existing backup conflicts, preserve it and report the error.

Use the 10–15-minute stability run to move between normal play, lessons, trainers, Assisted Play, coach/history and credits while changing volume and reduced motion. Record crashes, lost focus, repeated inputs, clipped text/audio or save warnings. A normal short run may not produce fifteen completed sessions or a rare deviation; mark those cases untested rather than filling in PASS. See [LEARNING_GUIDE](LEARNING_GUIDE.md), [SESSION_COACH](SESSION_COACH.md) and [AUDIO_AND_BRANDING](AUDIO_AND_BRANDING.md) for exact examples and limitations.

Target 60 FPS and predictable pacing; record measured data when available, otherwise mark performance as observed/manual. Lua heap is not total process RAM. Do not infer the handheld's memory/pacing budgets from Windows screenshots. SD-card sudden-power-loss durability remains unverified; A/B saves and readback are recovery measures, not a power-loss guarantee.

**After preparing this candidate, stop development and wait for these results.** Failing device prerequisites reopens the LÖVE decision; scope remains frozen.


## Preview.4 verification status

Use the repository's [final polish verification record](../artifacts/polish-evidence/FINAL_VERIFICATION.md) for the final source/package test totals, hashes, graphical evidence and remaining gates. If that record has not been produced, final verification is pending. Its Windows results do not approve the physical device. Preview.4 hardware tests and human listening remain uncompleted until the owner records results above.

## Historical preview.3 package evidence

The earlier 0.1.0-preview.3 record reported 282 source/package checks passing with zero failures; 10,000 simulated rounds without invariant violations; and 36 gates across 40,000 fresh shuffles within their predeclared bounds. Two packaged Windows launch/restart checks exited 0. ZIP layout/CRC, source bytes/notices, launcher LF/no BOM and stored 0755 mode passed local checks. These counts describe preview.3, not the new polish package. Its launcher had a separate static review; Bash was unavailable locally and hosted CI had not run. None of those checks constitutes a preview.4 device launch or performance approval.

The ZIP was created on Windows; its stored 0755 attributes do not prove that extraction or Wi-Fi upload preserves Linux executable permissions. Confirm actual launcher execution on muOS.
