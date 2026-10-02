# RG35XX H physical test record

**All results start NOT RUN.** Mark PASS only from direct observation. Use FAIL with a short explanation; inaccessible Start/Select should be recorded as such. Mapped labels appearing on screen do not prove the matching physical button was pressed.

## Setup and identity

Follow the package procedure in README.md: extract beside existing muOS Ports launchers; retain the sibling folder; use the existing PortMaster 11.5 runtime; make only this launcher executable where needed. No firmware edits or library replacement are part of this test.

| Record | Owner entry |
| --- | --- |
| Test date / tester | |
| Device | RG35XX H — confirm: |
| muOS version | Reported 2508.4 “Loose Goose” — confirm: |
| Kernel / architecture | Reported 4.9.170 aarch64 — confirm from launcher log: |
| SD card and actual Ports directory | |
| PortMaster version / actual directory | |
| LÖVE version / binary and package SHA-256 | Copy from launcher log where available: |
| Renderer / GPU / controller name, GUID, mapped status | Copy from report: |

## Required test sequence

Use a stopwatch for startup. Wait at least five seconds before recording timing. Leave TONE selected during the button test so A cannot accidentally confirm an exit. Test Start and Select **separately before trying any firmware exit chord**.

| Check | Exact action and expected observation | PASS / FAIL / NOT RUN; notes |
| --- | --- | --- |
| BOOT | Launch from muOS Ports. Diagnostic appears without an error screen. Record cold and warm startup seconds; provisional target is ≤5 s. | |
| RENDERING | Resolution says 640×480. Full header, input grid and four bottom actions visible; text readable; no clipping/stretching; three shapes move smoothly. | |
| FPS / TIMING | After warm-up record FPS, mean, p99 and >50 ms count. Target about 60 FPS with sensible pacing; 450 FPS is not a 60 Hz PASS. Loop p99 ≤20 ms is only a diagnostic proxy; inspect motion and record recurring stalls. | |
| CONTROLLER | Record detected name and `mapped` status. Native button events visible. If `mapped false`, capture raw observations and mark mapping incomplete; do not guess button numbers. | |
| D-PAD | Press UP, DOWN, LEFT, RIGHT individually. Matching seen label and last mapped event appear; releases are logged; focus responds one step per press. | |
| A / B / X / Y | Press each printed physical button individually. Record physical → displayed label below; each must match. A also activates the selected diagnostic action. | |
| L / R | Press each shoulder individually; verify corresponding L/R label and release. | |
| START / SELECT | Press separately, record mapping or firmware interception; no accidental exit during individual presses. | |
| AUDIO | Select TONE with D-pad, press A. At an ordinary audible device volume, actually hear the short tone. READY or an API success alone is insufficient. Record speaker/headphone path tested. | |
| SAVE | Record launch count N. Select SAVE, press A; write must say PASS. First launch prior read NONE is expected. No automatic success if write fails. | |
| REPORT | Select REPORT, press A. Message confirms writing. Preserve report/log before another launch overwrites them. | |
| EXIT | Select EXIT, press A once, then B to cancel; diagnostic remains. Select EXIT and press A twice; return to muOS frontend without hang, stray sound or frozen controls. Launcher log records exit code 0. | |
| RESTART + SAVE LOAD | Relaunch normally. Prior read PASS, launch count N+1, write PASS. Confirm the same save directory. This proves cross-process persistence. | |
| 10–15 MINUTE STABILITY | Leave running 10–15 minutes; periodically move focus, press controls and play tone. No crash, freeze, recurring long pauses or unexpected input. Write REPORT near start and end; copy each separately. Record timing/memory below. | |
| EXIT HELPER | After ordinary exit passes, relaunch, write REPORT, then use your already-known PortMaster/muOS exit chord. Return cleanly; verify controls/audio in frontend and relaunch. Do not invent a chord. Forced exit may omit the final report. | |

Physical labels are the printed RG35XX H labels. Fill each independently:

| Physical | Displayed mapped label / raw event | PASS / FAIL / inaccessible |
| --- | --- | --- |
| UP / DOWN / LEFT / RIGHT | | |
| A | | |
| B | | |
| X | | |
| Y | | |
| L | | |
| R | | |
| START | | |
| SELECT | | |

## Stability measurements

| Measurement | After ~1 minute | After 10–15 minutes |
| --- | --- | --- |
| FPS / loop mean / recent p99 ms | | |
| Full-run maximum ms / >50 ms intervals | | |
| Lua heap KiB | | |
| Process RSS / peak RSS KiB, or unavailable | | |
| Visible smoothness / input response / issues | | |

RSS should remain comfortably within the proposed 128 MiB ordinary / 192 MiB peak application budgets. This tiny screen leaves most future game costs untested; growth between two snapshots needs investigation rather than a guessed leak diagnosis. Lua heap alone cannot prove total memory fit. The checklist is a compatibility screen, not full product performance certification; presented-frame latency, 30-minute product load, SD durability and battery cost remain later measurements.

## Collect and send the results

1. Copy `royalpocketcompatibility/logs/launcher.log` **before launching again**.
2. Use its `Save directory:` line to locate `compatibility-report.txt` and `compatibility-save.txt`. Expected location is under `royalpocketcompatibility/data/love/royal-pocket-casino-compatibility/`, but the reported path is authoritative. Copy, do not delete them.
3. Return this filled checklist, logs and report. A photo of the screen can supplement text results. Include startup timings, physical button mapping and whether you actually heard the tone.
4. If anything fails, stop repeated blind attempts. Record the exact screen/error, failed step and launcher exit code. Do not change firmware or replace libraries to make the test pass.

## Failure record and engineering decision

| Field | Evidence / proposed follow-up |
| --- | --- |
| Exact failure and reproduction | |
| Error text / log / version / helper hash | |
| Likely cause, explicitly hypothesis unless proven | |
| Possible smallest workaround | |
| Complexity: small config fix / runtime repair / rebuild / firmware dependency | |
| Can community users install it without fragile system changes? | |
| Follow-up result and accepted/rejected workaround | |
| Verdict | KEEP LÖVE AS PROVISIONAL FAVORITE / RECONSIDER STACK / INSUFFICIENT EVIDENCE |

No physical result has been recorded by the author. Do not approve LÖVE from this unfilled checklist. After results, review failures and the separate Web/Android risks before any final architecture decision.
