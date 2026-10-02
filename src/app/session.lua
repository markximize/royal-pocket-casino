-- PURPOSE: Commit whole play/training progress before exposing it to UI.
-- CHANGE THIS MODULE WHEN: Lifecycle, retry or transaction ordering changes.
-- DO NOT PUT HERE: Blackjack formulas, card widgets or OS file operations.

local copy = require("src.plain_copy")
local round = require("src.blackjack.round")
local rules = require("src.blackjack.rules")
local seeded = require("src.random.seeded")
local statistics = require("src.progress.statistics")
local training_statistics = require("src.progress.training_statistics")
local migrations = require("src.persistence.migrations")
local schema = require("src.persistence.save_schema")
local store = require("src.persistence.save_store")
local chips = require("src.blackjack.chips")
local session = {}
local coach = require("src.progress.session_coach")
local strategy = require("src.training.basic_strategy")
local deviations = require("src.training.deviations")
local player_view = require("src.app.player_view")
local count_view = require("src.app.count_view")

-- ## PRESERVE THE OLD SAVE FORMAT

local function preserve_damaged_backup(storage, contents, version)
    local recovery_name = "recovery_backup_format_" .. version .. ".json"
    local size, size_error = storage.size(recovery_name)
    if size_error then
        return false, size_error
    end
    if size then
        if size > 1048576 then
            return false, "Oversized migration recovery copy preserved"
        end
        local existing, read_error = storage.read(recovery_name)
        if existing ~= contents then
            return false, read_error or "Migration recovery copy differs; originals preserved"
        end
        return true
    end
    local _, write_error = storage.write(recovery_name, contents)
    local preserved, read_error = storage.read(recovery_name)
    if preserved ~= contents then
        return false, write_error or read_error or "Cannot preserve damaged migration backup"
    end
    return true
end

local function preserve_migration_source(current)
    if not current.migration_from then
        return true
    end
    local source_size, source_size_error = current.storage.size(current.saved.slot)
    if source_size_error or not source_size then
        return false, source_size_error or "Migration source is missing; originals preserved"
    end
    if source_size > 1048576 then
        return false, "Oversized migration source preserved"
    end
    local source, source_error = current.storage.read(current.saved.slot)
    local original, reason, checksum = schema.decode(source, current.storage.hash)
    if
        not original
        or original.format_version ~= current.migration_from
        or checksum ~= current.saved.hash
    then
        return false, source_error or reason or "Migration source changed; reload before saving"
    end
    local backup_name = "backup_format_" .. current.migration_from .. ".json"
    local size, size_error = current.storage.size(backup_name)
    if size_error then
        return false, size_error
    end
    if size then
        if size > 1048576 then
            return false, "Oversized migration backup preserved"
        end
        local backup, read_error = current.storage.read(backup_name)
        if backup == source then
            return true
        end
        if not backup then
            return false, read_error or "Cannot read existing migration backup"
        end
        local saved_backup, _, backup_kind = schema.decode(backup, current.storage.hash)
        if saved_backup or backup_kind == "newer" then
            return false, "Existing migration backup differs; originals preserved"
        end
        local preserved, preserve_error =
            preserve_damaged_backup(current.storage, backup, current.migration_from)
        if not preserved then
            return false, preserve_error
        end
    end
    local _, write_error = current.storage.write(backup_name, source)
    local readback, read_error = current.storage.read(backup_name)
    if readback ~= source then
        return false, write_error or read_error or "Cannot verify the migration backup"
    end
    -- As with slot writes, exact readback resolves an uncertain acknowledgement.
    return true
end

local function commit(current, candidate)
    local valid, validation_error = schema.validate(candidate)
    if not valid then
        current.message = "Change rejected: " .. tostring(validation_error)
        return false, current.message
    end
    local preserved, backup_error = preserve_migration_source(current)
    if not preserved then
        current.pending = candidate
        current.message = "SAVE FAILED: " .. tostring(backup_error)
        return false, current.message
    end
    local saved, reason =
        store.commit(current.storage, current.saved, candidate, current.pending ~= nil)
    if not saved then
        current.pending = candidate
        current.message = "SAVE FAILED: " .. tostring(reason)
        return false, current.message
    end
    current.saved, current.snapshot, current.pending = saved, saved.snapshot, nil
    current.migration_from = nil
    current.message = saved.warning or "Saved locally"
    return true
end

function session.open(storage)
    local saved, load_error = store.load(storage)
    local current = { storage = storage, saved = saved, message = load_error }
    if not saved then
        return current
    end
    if not saved.empty then
        current.snapshot = migrations.to_current(saved.snapshot)
        local valid, reason = schema.validate(current.snapshot)
        if not valid then
            current.snapshot = nil
            current.message = "Save migration rejected: " .. tostring(reason)
            return current
        end
        if saved.snapshot.format_version < schema.version then
            current.migration_from = saved.snapshot.format_version
        end
        current.message = saved.warning or "Previous session restored"
        return current
    end
    local timestamp = storage.now()
    local candidate = {
        format_version = schema.version,
        game_id = "royal-pocket-casino",
        app_version = schema.app_version,
        engine_version = schema.engine_version,
        profile_id = storage.new_id(),
        lineage_id = storage.new_id(),
        writer_device_id = storage.device_id,
        revision = 1,
        parent_revision = 0,
        parent_snapshot_hash = "none",
        created_at = timestamp,
        updated_at = timestamp,
        chip_unit_scale = 10,
        starting_bankroll_units = 10000,
        statistics_version = 1,
        statistics = statistics.new(),
        training = training_statistics.new(),
        count_settings = migrations.count_defaults(),
        assistance = migrations.assistance_defaults(),
        coach = coach.new(),
        settings = { sound_enabled = true, volume = 5, reduced_motion = false },
        game = round.new(rules.defaults(), seeded.new(storage.new_seed()), seeded.next_integer),
    }
    commit(current, candidate)
    return current
end

local function candidate_snapshot(current)
    if not current.snapshot or current.pending then
        return nil, "Resolve the save error before playing"
    end
    if current.snapshot.revision >= chips.maximum then
        return nil, "Save revision limit reached"
    end
    local candidate = copy(current.snapshot)
    candidate.parent_revision = candidate.revision
    candidate.parent_snapshot_hash = current.saved.hash
    candidate.revision = candidate.revision + 1
    candidate.writer_device_id = current.storage.device_id
    candidate.app_version = schema.app_version
    candidate.updated_at = current.storage.now()
    return candidate
end

function session.command(current, kind, fields)
    local candidate, reason = candidate_snapshot(current)
    if not candidate then
        current.message = reason
        return false, reason
    end
    if kind == "deal" then
        if type(fields) ~= "table" or not chips.valid_bet(fields.bet_units) then
            current.message = "Bet must be 5 to 100 chips in steps of 5"
            return false, current.message
        end
        local allowed, limit_error = statistics.can_start(candidate.statistics, fields.bet_units)
        if not allowed then
            current.message = limit_error
            return false, limit_error
        end
    end
    local next_game, effect = round.apply(
        candidate.game,
        round.command(candidate.game, kind, fields),
        seeded.next_integer
    )
    if not next_game then
        current.message = effect
        return false, effect
    end
    -- Grade the pre-action decision, never its later winning or losing outcome.
    if kind == "hit" or kind == "stand" or kind == "double" or kind == "split" then
        local basic = strategy.recommend(candidate.game)
        if basic then
            local adjusted
            if candidate.assistance.mode == "advanced" and candidate.assistance.deviations then
                local visible = player_view.build(current)
                local counts = count_view.build(candidate.game, visible, candidate.count_settings)
                adjusted = deviations.recommend(candidate.game, counts, basic)
            end
            local next_coach, coach_error = coach.decision(candidate.coach, {
                category = basic.category,
                action = kind,
                expected = adjusted and adjusted.action or basic.action,
                basic_expected = basic.action,
                deviation_expected = adjusted and adjusted.action or nil,
            })
            if not next_coach then
                current.message = coach_error
                return false, coach_error
            end
            candidate.coach = next_coach
        end
    end
    candidate.game = next_game
    if effect.completed_round then
        statistics.record(candidate.statistics, effect.completed_round)
        local completed = effect.completed_round
        if not completed.result.void then
            local result = completed.result
            local naturals = 0
            for _, row in ipairs(result.hands) do
                if row.natural then
                    naturals = naturals + 1
                end
            end
            local next_coach, coach_error = coach.round(candidate.coach, {
                bet_units = completed.initial_bet_units,
                opening_bankroll_units = completed.opening_bankroll_units,
                net_units = result.net_units,
                staked_units = result.staked_units,
                outcome = result.net_units > 0 and "win"
                    or result.net_units < 0 and "loss"
                    or "push",
                blackjacks = naturals,
            })
            if not next_coach then
                current.message = coach_error
                return false, coach_error
            end
            candidate.coach = next_coach
        end
    end
    if effect.grant_units then
        if candidate.statistics.chip_grants_units > chips.maximum - effect.grant_units then
            current.message = "Chip grant limit reached"
            return false, current.message
        end
        candidate.statistics.chip_grants_units =
            chips.add(candidate.statistics.chip_grants_units, effect.grant_units)
    end
    return commit(current, candidate)
end

function session.settings(current, settings)
    local candidate, reason = candidate_snapshot(current)
    if not candidate then
        current.message = reason
        return false, reason
    end
    candidate.settings = copy(settings)
    return commit(current, candidate)
end

-- ## SAVE TRAINING WITHOUT CHANGING THE TABLE

function session.training_answer(current, kind, correct, category)
    local candidate, reason = candidate_snapshot(current)
    if not candidate then
        current.message = reason
        return false, reason
    end
    local next_training, scoring_error = training_statistics.record(
        candidate.training,
        kind == "deviation" and "strategy" or kind,
        correct
    )
    if not next_training then
        current.message = scoring_error
        return false, scoring_error
    end
    candidate.training = next_training
    local next_coach, coach_error = coach.training(candidate.coach, kind, correct, category)
    if not next_coach then
        current.message = coach_error
        return false, coach_error
    end
    candidate.coach = next_coach
    return commit(current, candidate)
end

function session.assistance_settings(current, preferences)
    local candidate, reason = candidate_snapshot(current)
    if not candidate then
        return false, reason
    end
    candidate.assistance = copy(preferences)
    return commit(current, candidate)
end

function session.new_coaching_session(current)
    local candidate, reason = candidate_snapshot(current)
    if not candidate then
        return false, reason
    end
    if candidate.game.phase ~= "betting" then
        return false, "Finish the round before starting a new coaching session"
    end
    local next_coach, coach_error = coach.close_session(candidate.coach)
    if not next_coach then
        current.message = coach_error
        return false, coach_error
    end
    candidate.coach = next_coach
    return commit(current, candidate)
end

function session.count_settings(current, settings)
    local candidate, reason = candidate_snapshot(current)
    if not candidate then
        current.message = reason
        return false, reason
    end
    candidate.count_settings = copy(settings)
    return commit(current, candidate)
end

function session.retry(current)
    if not current.pending then
        return false, "No pending write to retry"
    end
    return commit(current, current.pending)
end

return session
