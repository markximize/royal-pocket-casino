-- PURPOSE: Format honest diagnostic observations into one bounded text report.
-- CHANGE THIS MODULE WHEN: Evidence fields or metric definitions change.
-- DO NOT PUT HERE: File writing or automatic physical PASS verdicts.

local input = require("input")
local report = {}

function report.build(state)
    local lines = {
        "Royal Pocket Casino - compatibility diagnostic 1",
        "Physical RG35XX H compatibility: UNVERIFIED until owner records results",
        "LOVE: " .. state.runtime.version .. " / " .. state.runtime.codename,
        "OS reported by LOVE: " .. state.runtime.os,
        "Lua: " .. state.runtime.lua .. "; " .. state.runtime.jit,
        "Renderer: " .. state.runtime.renderer .. "; " .. state.runtime.renderer_version,
        "GPU: " .. state.runtime.vendor .. "; " .. state.runtime.graphics_device,
        "Save directory: " .. state.runtime.save_directory,
        string.format("Actual rendering dimensions: %d x %d", love.graphics.getDimensions()),
        string.format("Observed duration: %.1f seconds", state.elapsed),
        string.format("FPS (LOVE estimate): %d", love.timer.getFPS()),
        string.format(
            "Loop sample mean/p99: %.3f / %.3f ms",
            state.metrics.mean_ms,
            state.metrics.p99_ms
        ),
        string.format(
            "Full-run measured frames: %d; max %.3f ms; intervals >50ms: %d",
            state.metrics.frame_count,
            state.metrics.maximum_ms,
            state.metrics.over_50_ms
        ),
        "Timing is update-loop interval, NOT measured screen presentation or input latency.",
        string.format("Lua heap: %.1f KiB", state.memory.lua_kib),
        "Process RSS KiB: " .. tostring(state.memory.rss_kib or "unavailable"),
        "Peak process RSS KiB: " .. tostring(state.memory.peak_rss_kib or "unavailable"),
        "Save write/readback: " .. state.save.write_status,
        "Previous-launch read: " .. state.save.previous_read,
        "Launch count: " .. state.save.launch_count,
        "Previous saved count: " .. tostring(state.save.previous_launch_count or "none"),
        "Save error: " .. tostring(state.save.error or "none"),
        "Audio source created: " .. tostring(state.tone_ready),
        "Audio API error: " .. tostring(state.audio_error or "none"),
        "Audio requests: " .. state.tone_requests .. "; audible output: OWNER MUST VERIFY",
        "Last mapped event: " .. state.input.last_mapped,
        "Last raw event: " .. state.input.last_raw,
    }
    local seen_labels = {}
    for _, label in ipairs(input.labels) do
        seen_labels[#seen_labels + 1] = label
            .. "="
            .. (state.input.seen[label] and "observed" or "unobserved")
    end
    lines[#lines + 1] = "Mapped labels (not physical confirmation): "
        .. table.concat(seen_labels, ", ")
    for _, controller in ipairs(state.input.controllers) do
        lines[#lines + 1] = string.format(
            "Controller %s: %s; GUID %s; mapped %s; buttons %d; axes %d; hats %d",
            controller.id,
            controller.name,
            controller.guid,
            tostring(controller.mapped),
            controller.buttons,
            controller.axes,
            controller.hats
        )
    end
    lines[#lines + 1] = "Recent input events (bounded to 80):"
    for _, message in ipairs(state.input.log) do
        lines[#lines + 1] = message
    end
    return table.concat(lines, "\n") .. "\n"
end

return report
