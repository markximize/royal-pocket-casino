#!/bin/bash
# PURPOSE: Launch the V0.1 test candidate through the installed PortMaster helper.
# CHANGE THIS FILE WHEN: Device evidence requires a different integration.
# DO NOT PUT HERE: Firmware changes, library downloads or game logic.

# This candidate is deliberately installed on SD1 using muOS's port-data layout.
GAMEDIR="/mnt/mmc/ports/royalpocketcasino"
if [[ ! -d "$GAMEDIR" ]]; then
    printf 'Missing SD1 game folder: %s\n' "$GAMEDIR" >&2
    exit 1
fi
mkdir -p "$GAMEDIR/logs" || exit 1
exec > "$GAMEDIR/logs/launcher.log" 2>&1 || exit 1

fail() {
    printf 'FAIL: %s\nRead royalpocketcasino/logs/launcher.log\n' "$1"
    sleep 3
    exit 1
}

printf 'Royal Pocket Casino V0.1 test candidate launcher (hardware approval pending)\n'
printf 'Package directory: %s\n' "$GAMEDIR"
uname -a

# ## FIND THE EXISTING PORTMASTER INSTALLATION
# Paths are documented candidates, not promises about this particular SD card.
# An explicit override wins; ambiguous installations are rejected.
if [[ -f "$GAMEDIR/portmaster-path.txt" ]]; then
    IFS= read -r controlfolder < "$GAMEDIR/portmaster-path.txt"
    controlfolder="${controlfolder%$'\r'}"
else
    candidates=(
        /mnt/mmc/MUOS/PortMaster
        /opt/system/Tools/PortMaster
        /opt/tools/PortMaster
        "${XDG_DATA_HOME:-$HOME/.local/share}/PortMaster"
        /roms/ports/PortMaster
    )
    found=()
    for candidate in "${candidates[@]}"; do
        if [[ -f "$candidate/control.txt" ]]; then
            found+=("$candidate")
        fi
    done
    [[ ${#found[@]} -eq 1 ]] || fail "Expected one PortMaster installation; put its actual path in portmaster-path.txt"
    controlfolder="${found[0]}"
fi
[[ -f "$controlfolder/control.txt" ]] || fail "Missing control.txt at selected PortMaster path"
printf 'Selected PortMaster: %s\n' "$controlfolder"
export controlfolder

source "$controlfolder/control.txt" || fail "PortMaster control.txt initialization failed"
[[ "$DEVICE_ARCH" == "aarch64" ]] || fail "Expected aarch64, PortMaster reported: $DEVICE_ARCH"
if [[ -f "$controlfolder/mod_${CFW_NAME}.txt" ]]; then
    source "$controlfolder/mod_${CFW_NAME}.txt" || fail "PortMaster CFW initialization failed"
fi
declare -F get_controls >/dev/null || fail "PortMaster get_controls is unavailable"
get_controls || fail "PortMaster controller setup failed"
printf 'Effective PortMaster after initialization: %s\n' "$controlfolder"

# ## USE THE DOCUMENTED LOVE 11.5 HELPER
runtime_helper="$controlfolder/runtimes/love_11.5/love.txt"
[[ -f "$runtime_helper" ]] || fail "Missing love_11.5/love.txt; inspect/update PortMaster through its normal interface"
source "$runtime_helper" || fail "LOVE runtime helper failed"
[[ -n "$RUNTIME_DIR" && -x "$LOVE_BINARY" ]] || fail "LOVE helper did not provide an executable runtime"
[[ -d "$RUNTIME_DIR/libs.$DEVICE_ARCH" ]] || fail "LOVE runtime library directory is missing"
[[ -f "$GAMEDIR/game.love" ]] || fail "Missing game.love"

printf 'LOVE_VERSION: %s\nLOVE_BINARY: %s\nRUNTIME_DIR: %s\n' "$LOVE_VERSION" "$LOVE_BINARY" "$RUNTIME_DIR"
printf 'CFW_NAME: %s\nDEVICE_ARCH: %s\n' "$CFW_NAME" "$DEVICE_ARCH"
if command -v sha256sum >/dev/null; then
    sha256sum "$runtime_helper" "$LOVE_BINARY" "$GAMEDIR/game.love"
fi
if command -v ldd >/dev/null; then
    ldd "$LOVE_BINARY"
fi

# Only this game's data location changes; installation never touches saves.
mkdir -p "$GAMEDIR/data" || fail "Game data directory is not writable"
export XDG_DATA_HOME="$GAMEDIR/data"
export SDL_GAMECONTROLLERCONFIG="${sdl_controllerconfig:-${SDL_GAMECONTROLLERCONFIG:-}}"
export LD_LIBRARY_PATH="$RUNTIME_DIR/libs.$DEVICE_ARCH${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
cd "$GAMEDIR" || fail "Cannot enter game directory"

# ## EXIT HELPER AND SAFE CLEANUP
# Keep native gamepad events: no keyboard-emulation profile is installed.
# Do not call global killall or pm_finish (its current implementation restarts a service).
mapper_pid=""
cleanup() {
    if [[ -n "$mapper_pid" ]]; then
        kill "$mapper_pid" 2>/dev/null || true
        wait "$mapper_pid" 2>/dev/null || true
    fi
}
trap cleanup EXIT
if [[ -n "$GPTOKEYB" && -n "$LOVE_GPTK" ]]; then
    read -r -a mapper_command <<< "$GPTOKEYB"
    "${mapper_command[@]}" "$LOVE_GPTK" &
    mapper_pid=$!
else
    printf 'WARNING: PortMaster exit helper unavailable; use the on-screen EXIT action.\n'
fi
if declare -F pm_platform_helper >/dev/null; then
    pm_platform_helper "$LOVE_BINARY"
fi

"$LOVE_BINARY" "$GAMEDIR/game.love" --handheld
love_status=$?
printf 'LOVE exit status: %d\n' "$love_status"
exit "$love_status"
