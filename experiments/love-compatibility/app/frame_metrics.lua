-- PURPOSE: Measure update-loop intervals with a small bounded sample window.
-- CHANGE THIS MODULE WHEN: The measurement window/report definitions change.
-- DO NOT PUT HERE: LÖVE calls, rendering, or hardware compatibility verdicts.

local frame_metrics = {}
local window_capacity = 1200

function frame_metrics.new()
    return {
        elapsed = 0,
        samples = {},
        next_sample = 1,
        frame_count = 0,
        maximum_ms = 0,
        over_50_ms = 0,
        mean_ms = 0,
        p99_ms = 0,
    }
end

-- ## LOOP TIMING

function frame_metrics.record(metrics, delta_seconds)
    metrics.elapsed = metrics.elapsed + delta_seconds
    -- Startup work is recorded separately; a fresh window needs a short warm-up.
    if metrics.elapsed < 2 then
        return
    end
    metrics.samples[metrics.next_sample] = delta_seconds * 1000
    metrics.next_sample = metrics.next_sample % window_capacity + 1
    metrics.frame_count = metrics.frame_count + 1
    metrics.maximum_ms = math.max(metrics.maximum_ms, delta_seconds * 1000)
    if delta_seconds > 0.050 then
        metrics.over_50_ms = metrics.over_50_ms + 1
    end
end

function frame_metrics.refresh(metrics)
    if #metrics.samples == 0 then
        return
    end
    local sorted_samples = {}
    local total_ms = 0
    for index, sample_ms in ipairs(metrics.samples) do
        sorted_samples[index] = sample_ms
        total_ms = total_ms + sample_ms
    end
    table.sort(sorted_samples)
    metrics.mean_ms = total_ms / #sorted_samples
    metrics.p99_ms = sorted_samples[math.ceil(#sorted_samples * 0.99)]
end

return frame_metrics
