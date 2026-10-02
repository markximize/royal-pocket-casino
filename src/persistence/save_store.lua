-- PURPOSE: Select/recover and read-back whole A/B save generations.
-- CHANGE THIS MODULE WHEN: Slot selection or commit acknowledgement changes.
-- DO NOT PUT HERE: Game rules, timestamps as ordering or guaranteed power-loss claims.

local schema = require("src.persistence.save_schema")
local store = {}
local slot_names = { "save_a.json", "save_b.json" }

function store.load(storage)
    local valid, invalid = {}, {}
    local any_file = false
    for _, name in ipairs(slot_names) do
        local size, size_error = storage.size(name)
        if size_error then
            return nil, size_error
        end
        if size then
            any_file = true
            if size > 1048576 then
                return nil, "Oversized save preserved: " .. name
            end
            local contents, read_error = storage.read(name)
            if not contents then
                return nil, read_error or "Cannot read existing save"
            end
            local snapshot, reason, checksum = schema.decode(contents, storage.hash)
            if checksum == "newer" then
                return nil, reason
            end
            if snapshot then
                valid[#valid + 1] = { snapshot = snapshot, hash = checksum, slot = name }
            else
                invalid[#invalid + 1] = { slot = name, bytes = contents, reason = reason }
            end
        end
    end
    if #valid == 0 then
        if any_file then
            return nil, "No valid save; originals preserved. Restore a known-valid backup."
        end
        return { empty = true, invalid = {} }
    end
    table.sort(valid, function(left, right)
        return left.snapshot.revision > right.snapshot.revision
    end)
    local selected = valid[1]
    if valid[2] then
        local other = valid[2]
        if
            selected.snapshot.profile_id ~= other.snapshot.profile_id
            or selected.snapshot.lineage_id ~= other.snapshot.lineage_id
            or (
                selected.snapshot.revision == other.snapshot.revision
                and selected.hash ~= other.hash
            )
        then
            return nil, "Conflicting save identities/revisions preserved"
        end
        if
            selected.snapshot.revision ~= other.snapshot.revision
            and (
                selected.snapshot.parent_revision ~= other.snapshot.revision
                or selected.snapshot.parent_snapshot_hash ~= other.hash
            )
        then
            return nil, "Save ancestry does not match the previous generation"
        end
    end
    selected.invalid = invalid
    if #invalid > 0 then
        selected.warning = "Recovered revision "
            .. selected.snapshot.revision
            .. "; corrupt slot preserved"
    end
    return selected
end

function store.commit(storage, previous, candidate, reconcile_pending)
    local envelope, encode_error, expected_hash = schema.encode(candidate, storage.hash)
    if not envelope then
        return nil, encode_error
    end
    local observed, load_error = store.load(storage)
    if not observed then
        return nil, load_error
    end
    if reconcile_pending and observed.hash == expected_hash then
        return observed
    end
    if observed.hash ~= previous.hash or observed.empty ~= previous.empty then
        return nil, "Save changed in another instance; close this instance and reload"
    end
    for _, invalid in ipairs(observed.invalid) do
        local preserved, preserve_error = storage.write("recovery_" .. invalid.slot, invalid.bytes)
        if not preserved then
            return nil, preserve_error or "Cannot preserve damaged slot"
        end
    end
    local target = previous.slot == "save_a.json" and "save_b.json" or "save_a.json"
    local written, write_error = storage.write(target, envelope)
    -- Reconcile even a reported write failure: it may have persisted completely.
    local readback, read_error = storage.read(target)
    local snapshot, validation_error, checksum = schema.decode(readback, storage.hash)
    if not snapshot or checksum ~= expected_hash then
        return nil, write_error or read_error or validation_error or "Save readback differs"
    end
    return {
        snapshot = snapshot,
        hash = checksum,
        slot = target,
        invalid = {},
        warning = not written and "Write reported a failure; exact candidate verified on readback"
            or nil,
    }
end

return store
