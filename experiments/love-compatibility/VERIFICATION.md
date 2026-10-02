# Compatibility verification record

**Date: 2026-10-01. Physical device: not accessed or tested.**

Verdict: **KEEP LÖVE AS PROVISIONAL FAVORITE**, conditional on physical tests and the later portability/Web/Android experiments. No production architecture approval, independent review, audit, release certification or completed hardware test is claimed.

## Executed environment

Windows host, official portable LÖVE **11.5.0 / Mysterious Mysteries**, Lua **5.1 syntax via LuaJIT 2.1.1700008891**. Renderer reported OpenGL **3.3.0 - Build 32.0.101.7085**, Intel Iris Xe Graphics.

Downloaded development tools live in ignored `.local-tools/` and are absent from transfer archives:

| Tool | Source and local SHA-256 |
| --- | --- |
| LÖVE 11.5 Windows x64 ZIP, 4,512,260 bytes | [Official release asset](https://github.com/love2d/love/releases/download/11.5/love-11.5-win64.zip) · `BA6E56BE2685E53C817749C4A5007F51137136FE5A3AB64920508BABC2E74369` |
| StyLua 2.5.2 Windows x64 ZIP | [Official release](https://github.com/JohnnyMorganz/StyLua/releases/tag/v2.5.2) · `E77D0EA1226B8B389B43F702240091249A96EEA25857281F90EA24D0EB9EB969` |

These are locally calculated download hashes. The LÖVE release metadata did not provide a digest for comparison; the hash is not signature verification.

## Checks and outcomes

| Check | Actual result |
| --- | --- |
| StyLua parser / formatting | PASS with `.stylua.toml`, Lua51 syntax, Unix endings, four-space indentation, 100-column target. No Luacheck/type analysis was executed. |
| Small self-test suite under LÖVE | PASS: module export regression, test-save format/version/range, launch increments, preservation of corrupted input, simulated write failure, bounded timing window, long-interval counting, mapped/raw/keyboard evidence separation, bounded input log, real filesystem write/read/remove of a separate fixture. |
| Save across separate desktop processes | PASS: two repaired source runs loaded prior counts 1→2 and 2→3; final packaged run loaded 3→4. The real diagnostic save was retained. |
| Desktop rendering | PASS: 640×480 dimensions reported; captured screenshot inspected for readable text, layout and shapes. Tiny animation ran in the actual framework. Controller/touch interaction was not manually verified. |
| Audio API | Original tone source created and playback requested without an API exception. **Audible output not verified.** |
| Application lifecycle | Each repaired source smoke process and final packaged smoke process exited normally with code 0 after about five seconds. On-screen exit controls and muOS frontend return are still unverified. |
| Packaging | `.love` and transfer ZIP built. CRC checks passed; `.love` entries matched the nine source files byte-for-byte; main.lua at root; nested payload identical; shell file starts with a Unix shebang, LF endings and no BOM; notices present; no runtime binaries or saves included. |
| Build script | PowerShell parse and actual archive build passed. |
| Bash launcher | Inspected against pinned PortMaster upstream sources. **No Bash syntax/execution check**: no Bash runtime available, WSL not installed. Actual helper interaction is unverified. |

An initial desktop run exposed a real defect: `report.lua` lacked its module-table return, so quitting attempted to use Lua's boolean `require` result and opened the framework error screen. The missing return was restored, a focused regression assertion added, and clean process exits verified afterward. This was an application defect, not a LÖVE compatibility failure.

## Final packaged desktop observation

Tested `.love` payload: **11,746 bytes**.

SHA-256: `7E150A89AB8495FAC94063110FAC7FF1D85187E428D92CB80D30DAD759544D20`.

| Field | Reported value |
| --- | --- |
| Duration / actual dimensions | 5.0 seconds / 640×480 |
| FPS estimate at final report | 452 |
| Recent loop mean / p99 | 2.160 / 3.033 ms |
| Measured frames after warm-up | 1,390 |
| Full-run max / intervals >50 ms | 26.199 ms / 0 |
| Lua heap | 467.7 KiB |
| Process RSS / peak RSS | Unavailable on this Windows measurement path |
| Prior read / write-readback | PASS / PASS |
| Prior / current launch count | 3 / 4 |
| Controller detection | None attached; no physical input observations |
| Audio | Source created, one request, no API exception; hearing unverified |

VSync was requested, but this environment ran far above 60 loop FPS. These results establish neither refresh-synchronized pacing nor the RG35XX H performance budget. The screenshot and report are different moments, so instantaneous FPS/heap values differ. No cause was established for the pacing result.

Ignored local evidence files: `artifacts/desktop-package-report.txt`, `artifacts/desktop-package.png`, plus the preceding repaired source-run reports/screenshots. `build.ps1` prints hashes for both transfer artifacts; transfer-ZIP bytes can change when packaged documentation changes. The payload hash above identifies the application actually executed.

## Reproduce local checks

Use the official 11.5 runtime and StyLua 2.5.2:

```powershell
stylua --check --config-path experiments/love-compatibility/.stylua.toml experiments/love-compatibility/app
& .\experiments\love-compatibility\build.ps1
lovec experiments/love-compatibility/artifacts/royal-pocket-compatibility.love --self-test
```

For the optional automated graphical smoke run, set `RPC_POC_REPORT_DIR` to an existing writable artifact folder before launching the `.love` file with `--smoke-test`. It requests the tone after one second, captures a screenshot after four seconds and exits after five seconds. Clear the variable afterward. This run increments the isolated diagnostic launch counter and writes the usual report. A manual run needs no environment variable.

## Unverified gates and risks

- Every physical checklist item: exact muOS installation/runtime, ARM loader, graphics backend, mappings, D-pad/ABXY/LR/StartSelect, hearing, actual data path, SD persistence, startup timing, memory, ordinary exit, exit chord and 10–15 minute stability.
- The Linux launcher has not run. Standard helper calls, optional mapper behavior, executable permissions and child-only cleanup can fail. We do not promise an installable community release from this ZIP.
- Long-run desktop stability, real input latency, actual presented-frame intervals, GPU/total system memory, battery cost and abrupt-power-loss durability were not measured.
- Pure Lua fixtures on a standalone Lua 5.1 interpreter, handheld LuaJIT and browser Lua were not cross-compared. Current tests run under Windows LuaJIT only.
- No Web compile/runtime/IndexedDB/offline-caching or Android APK/lifecycle test has run. Their upstream routes remain plausible, with maintenance risk explicitly open.
- This is author verification. Independent and owner review remain outstanding. Licensing decisions are still pending; third-party notices are preparation, not public-release authorization.

Next action: the owner executes DEVICE_TEST.md and returns the checklist, report and launcher log. Stop production implementation until the resulting decisions are resolved.
