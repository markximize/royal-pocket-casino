# LÖVE compatibility diagnostic

**Experiment 1 · 2026-10-01 · physical RG35XX H result pending**

Verdict: **KEEP LÖVE AS PROVISIONAL FAVORITE.** Desktop execution is encouraging; handheld compatibility, browser delivery and Android delivery remain unapproved. This is an isolated diagnostic, with no Blackjack, production saves, backend or UI framework.

## Run on a development machine

Install or extract the [official LÖVE 11.5 runtime](https://github.com/love2d/love/releases/tag/11.5). From the repository root:

```powershell
love .\experiments\love-compatibility\app
love .\experiments\love-compatibility\app --self-test
```

If LÖVE is not on PATH, replace `love` with its full executable path. Windows `lovec.exe` displays console test output; `love.exe` runs the same application. On Linux/macOS use `love experiments/love-compatibility/app`. Those platforms' execution has not been verified here.

Keyboard: arrows select TONE / SAVE / REPORT / EXIT; Enter activates; EXIT requires a second Enter; Escape cancels an exit confirmation or exits normally. A mapped controller uses D-pad and A; B cancels exit confirmation. Other buttons are observations only. Controller button tests may also activate the highlighted action, so leave TONE selected while testing buttons.

TONE requests an original 440 Hz, quarter-second sound. **You must confirm hearing it.** A successful API call is not proof of speaker output. REPORT writes evidence; clean exit also writes it. No screenshots are taken during an ordinary run.

## Structure and boundaries

| File | Responsibility |
| --- | --- |
| `app/conf.lua` | Runtime modules, diagnostic identity, native 640×480 window, requested VSync, optional handheld fullscreen |
| `app/main.lua` | Framework callbacks, four diagnostic actions, clean exit and optional desktop smoke run |
| `app/screen.lua` | One readable screen, seen-label indicators, text, shapes and three moving objects |
| `app/input.lua` | Controller inventory, mapped/raw events, bounded input log; no guessed physical button indices |
| `app/frame_metrics.lua` | Plain Lua timing math with bounded history |
| `app/save_format.lua` | Plain Lua validation/serialization of the tiny versioned diagnostic save |
| `app/platform.lua` | LÖVE and OS observations, local storage, generated tone, optional desktop artifact export |
| `app/report.lua` | Honest text evidence; never automatically approves physical tests |
| `app/self_test.lua` | Small scenario checks for these diagnostic contracts |
| `launcher/Royal Pocket Casino Compatibility.sh` | Existing PortMaster integration only |
| `build.ps1` | Built-in .NET ZIP packaging, without runtime downloads or production builds |

`frame_metrics.lua` and `save_format.lua` use portable Lua syntax without LÖVE/OS calls. This illustrates the future domain boundary; it does not prove future engine semantics on every Lua runtime. LÖVE-facing modules can share framework APIs across native platforms, while storage, browser lifecycle and input behavior will still need platform testing. There are no classes, plugin systems or imported Lua libraries.

For Python learners: a Lua module returns its public table, and `require` loads it. Start with `save_format.lua`, then follow `platform.begin_launch()` to see how parsing and storage stay separate. The source headers explain where changes belong.

## What the screen and report measure

- Actual LÖVE rendering dimensions, framework version, OS, Lua/LuaJIT and renderer/GPU strings.
- LÖVE FPS estimate and update-loop intervals. After a two-second warm-up, mean and nearest-rank p99 use the latest **1,200 samples**, refreshed once per second. At 60 FPS this covers about 20 seconds; faster loops cover less time. Maximum interval and intervals exceeding 50 ms cover the full measured run after warm-up.
- Lua-managed heap from `collectgarbage("count")`. This excludes native graphics/audio/runtime memory. Linux additionally reads process RSS and peak RSS from `/proc/self/status` once per second if available. It does not measure children, system memory, GPU memory or battery usage; missing observations say unavailable.
- Controller name, GUID, mapped status, button/axis/hat counts. Seen labels indicate mapped press callbacks; physical label correctness needs the owner's checklist. Raw buttons/hats remain visible if SDL mapping is missing. Axis values at magnitude ≥0.75 update the last raw observation. Reports retain the latest 80 logged button/hat/keyboard events.

**Loop timing is not presented-frame timing or input latency.** The PoC requests VSync but the tested Windows environment ran around 450 loop FPS. High FPS alone is not a success criterion. Device tests must establish sensible pacing and smooth visible motion; if VSync is ineffective there, a small deliberate frame limiter would need a separate measured fix. This PoC cannot certify the specification's presented-frame p99 budget.

## Tiny save and evidence files

LÖVE identity: `royal-pocket-casino-compatibility`.

```text
save_version=1
launch_count=3
last_successful_test=launch
```

`compatibility-save.txt` loads before startup increments its count. The screen distinguishes **write/readback** from **prior-launch read**. First launch prior read is NONE, not a failure. SAVE writes `manual_write` without incrementing the launch count. The last-test token describes this storage action; it never means all hardware checks passed.

Unknown versions or malformed saves are preserved and block writes. There is no migration, backup rotation, atomic replacement or power-loss guarantee in this experiment. Do not use these writes as the production save implementation.

`compatibility-report.txt` contains the latest REPORT or clean-exit snapshot. Earlier reports are overwritten, so copy results before another test. The exact save directory is printed at startup and in the report. Typical desktop LÖVE paths are under the user's local application-data directory; follow the reported path rather than guessing.

The handheld launcher sets `XDG_DATA_HOME` to its own `royalpocketcompatibility/data` folder. LÖVE is expected to put identity data below `data/love/royal-pocket-casino-compatibility/`; **confirm the actual reported path on the device**. `logs/launcher.log` is also replaced on each launch. Both locations are outside the shared runtime and `.love` archive. No production player data is touched.

## Build a transfer package

From the repository root, with PowerShell:

```powershell
& .\experiments\love-compatibility\build.ps1
```

Outputs in ignored `artifacts/`:

- `royal-pocket-compatibility.love`: nine small Lua files, with `main.lua` at archive root. Run with `love <path-to-archive>`.
- `royal-pocket-compatibility-rg35xx-h.zip`: launcher, sibling content folder, instructions and third-party notices. No LÖVE, PortMaster or system library binaries are included.

The build does not sign or publish anything. Hashes identify the tested package; they are not an upstream signature or certification. If PowerShell execution is restricted, use your approved script-running method; this procedure does not require changing machine-wide execution policy.

## Handheld package and launch procedure

1. Back up your SD card as you normally would. Locate the **actual muOS Ports directory containing existing launch scripts**. This experiment does not assume which card or mount holds it.
2. Extract the transfer ZIP into that directory. Keep these siblings together:

   ```text
   <actual Ports directory>/
     Royal Pocket Casino Compatibility.sh
     royalpocketcompatibility/
       compatibility.love
       README.md
       DEVICE_TEST.md
       VERIFICATION.md
       THIRD_PARTY_NOTICES.md
       notices/
   ```

3. Check the existing PortMaster installation. The launcher searches documented candidate directories and requires one `control.txt`; ambiguous or missing installations stop with a message in `logs/launcher.log`. If necessary, create `royalpocketcompatibility/portmaster-path.txt` containing **one confirmed absolute path to the installed PortMaster directory**. The installed control helper may select its own effective path; both selected and effective paths are logged.
4. The installed runtime must provide `runtimes/love_11.5/love.txt`, its selected executable `love.aarch64`, and `libs.aarch64/`. If absent, stop and consult PortMaster's normal runtime setup/update procedure. “PortMaster updated” does not prove this optional runtime is present. Do not rename an older runtime, guess download commands, replace system libraries or modify firmware.
5. Where executable bits apply, make **only this new launcher** executable using your file-transfer tool or `chmod +x` on its confirmed full path. ZIP extraction does not preserve an executable permission here. Launch it through the muOS Ports interface, then follow [DEVICE_TEST](DEVICE_TEST.md).

The launcher logs kernel/architecture, PortMaster helper paths, runtime identity, optional SHA-256 values, dependency output from `ldd` if available, application console output and normal exit status. Failures stay in that folder. A desktop Bash parser/execution was not available; the actual launcher and its helper interaction must be tested on Linux/device.

### Why runtime files are necessary

The `.love` file is Lua source in a ZIP, not an ARM executable. PortMaster supplies the engine compiled for aarch64, LuaJIT and relevant shared libraries. The inspected helper prepends its library directory to `LD_LIBRARY_PATH`; the launcher follows that arrangement with a quoted executable path. The inspected runtime tree includes `liblove-11.5.so`, `libluajit-5.1.so.2`, `libmodplug.so.1` and `libogg.so.0`. Other platform dependencies may come from firmware; **the actual installation and loader output decide what is available**. No speculative libraries are bundled.

The existing PortMaster helper supplies SDL mappings and an exit helper. This diagnostic installs no keyboard-emulation profile; controller observations are native. It tracks and terminates only the mapper child it started. It deliberately does not call the inspected `pm_finish`, which performs broader service cleanup. Returning to muOS and the exit chord therefore need explicit testing. If cleanup is insufficient, stop and collect evidence before changing this integration.

## Evidence classification

| Class | Evidence / limitation |
| --- | --- |
| KNOWN — reported by owner | RG35XX H, muOS 2508.4 “Loose Goose”, kernel 4.9.170 aarch64, updated PortMaster, Wi-Fi. These facts have not been remotely inspected. |
| KNOWN — locally executed | Official Windows LÖVE 11.5 runs the diagnostic, renders 640×480, writes and loads the test save across separate processes, requests audio and exits cleanly. See [VERIFICATION](VERIFICATION.md). |
| DOCUMENTED | Official PortMaster packaging guide uses `love_11.5/love.txt`, `$LOVE_GPTK`, `pm_platform_helper` and `$LOVE_RUN`. Inspected upstream helper selects architecture-specific binaries and libraries. This establishes a plausible route, not RG35XX H support. |
| ASSUMED | The user's installation has a compatible 11.5 runtime, dependencies/graphics driver and useful SDL mapping; setting XDG data home behaves as expected; child-only cleanup returns to frontend. All can fail. |
| MUST BE VERIFIED ON DEVICE | Startup, full display, frame pacing, memory, controller labels, audio hearing, persistent writable path, restart, exit/cleanup and 10–15 minute stability. |

Research baseline: [PortMaster packaging guide](https://portmaster.games/packaging.html), and PortMaster-GUI commit **1d7106ac7552f745f41e5558f7bc2d45e7f66ea5**: [runtime helper](https://github.com/PortsMaster/PortMaster-GUI/blob/1d7106ac7552f745f41e5558f7bc2d45e7f66ea5/PortMaster/runtimes/love_11.5/love.txt), [muOS controls](https://github.com/PortsMaster/PortMaster-GUI/blob/1d7106ac7552f745f41e5558f7bc2d45e7f66ea5/PortMaster/muos/control.txt), [muOS integration](https://github.com/PortsMaster/PortMaster-GUI/blob/1d7106ac7552f745f41e5558f7bc2d45e7f66ea5/PortMaster/mod_muOS.txt). Installed files can differ; preserve their logged hashes alongside results. Older PortMaster porting notes reference 11.4, so they were not treated as the current launcher contract.

## Future platforms and decision after this test

- **Desktop:** convenient shared LÖVE development route. Only Windows was executed here.
- **RG35XX H:** proposed shared Lua application plus launcher/input/storage integration. Acceptance requires physical results, not the presence of an aarch64 binary upstream.
- **Web:** [love.js](https://github.com/Davidobot/love.js) is a community route, with browser audio gestures, persistence, runtime/version support, payload and offline caching still requiring a separate small experiment. The native `.love` run does not validate it. The Linux `/proc` read must remain native-only. Browser-compatible pure Lua must avoid native modules and OS dependencies.
- **Android:** [official love-android](https://github.com/love2d/love-android) is a plausible native route. APK toolchain, touch/safe areas, pause/resume, storage and audio need a later small build/device test. No APK or Web build was produced here.

Keeping pure Lua rules apart from these adapters preserves a route to both future targets. It does not guarantee their practicality. Do not finally approve the stack without the separate portability/Web/Android gates in PROJECT_SPEC.

If the device fails, record the exact symptom and logs in DEVICE_TEST. A missing optional runtime or incorrect SDL mapping may have a small, supportable remedy. Needing firmware edits, a private engine fork or fragile device-library replacements would be a significant community-distribution problem. Do not declare an acceptable workaround without testing it.

If LÖVE is unreasonable after that evidence, compare the **same diagnostic**, not a game: Godot/GDScript offers stronger built-in cross-platform tooling but needs proof of H700 graphics/runtime cost; raylib/C offers a small native path but brings compilation, cross-platform builds, memory ownership and harder learning costs. No failed hardware evidence currently justifies switching or implementing either alternative.

**Stop here. Await the owner's physical checklist and logs; do not begin Blackjack.**
