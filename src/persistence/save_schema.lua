-- PURPOSE: Validate supported whole-progress snapshots and SHA-256 envelopes.
-- CHANGE THIS MODULE WHEN: Saved fields or compatible version semantics change.
-- DO NOT PUT HERE: Slot writes, silent migrations, defaults for corrupt data.

local check = require("src.check")
local json = require("src.persistence.safe_json")
local game_validation = require("src.persistence.game_validation")
local chips = require("src.blackjack.chips")
local statistics = require("src.progress.statistics")
local training_statistics = require("src.progress.training_statistics")
local session_coach = require("src.progress.session_coach")
local schema = { version = 3, app_version = "0.1.0-preview.4", engine_version = "1" }

local function validate_assistance(settings)
    if
        not check.object(settings, {
            "mode",
            "strategy_hints",
            "explanations",
            "deviations",
            "check_count",
        })
        or (settings.mode ~= "off" and settings.mode ~= "basic" and settings.mode ~= "advanced")
    then
        return false, "Invalid Assisted Play settings"
    end
    for _, name in ipairs({ "strategy_hints", "explanations", "deviations", "check_count" }) do
        if not check.boolean(settings[name]) then
            return false, "Invalid Assisted Play preference"
        end
    end
    return true
end

local function validate_count_settings(settings)
    if
        not check.object(settings, {
            "show_running",
            "show_true",
            "show_decks",
            "rounding",
            "deck_step",
            "level",
            "pace",
            "assistance",
        })
    then
        return false, "Invalid count settings fields"
    end
    local valid_level = settings.level == "beginner"
        or settings.level == "practice"
        or settings.level == "advanced"
    local valid_pace = settings.pace == "slow"
        or settings.pace == "comfortable"
        or settings.pace == "fast"
    if
        not check.boolean(settings.show_running)
        or not check.boolean(settings.show_true)
        or not check.boolean(settings.show_decks)
        or not check.boolean(settings.assistance)
        or settings.rounding ~= "truncate"
        or settings.deck_step ~= 0.5
        or not valid_level
        or not valid_pace
    then
        return false, "Invalid count settings"
    end
    return true
end

function schema.validate(snapshot)
    if type(snapshot) ~= "table" then
        return false, "Unsupported save contract"
    end
    local extra_fields = {}
    if snapshot.format_version == 2 then
        extra_fields = { "training", "count_settings" }
    elseif snapshot.format_version == 3 then
        extra_fields = { "training", "count_settings", "assistance", "coach" }
    end
    local supported_version = snapshot.format_version == 1
        or snapshot.format_version == 2
        or snapshot.format_version == schema.version
    if
        not check.object(snapshot, {
            "format_version",
            "game_id",
            "app_version",
            "engine_version",
            "profile_id",
            "lineage_id",
            "writer_device_id",
            "revision",
            "parent_revision",
            "parent_snapshot_hash",
            "created_at",
            "updated_at",
            "chip_unit_scale",
            "starting_bankroll_units",
            "statistics_version",
            "statistics",
            "settings",
            "game",
        }, extra_fields)
        or not supported_version
        or snapshot.game_id ~= "royal-pocket-casino"
        or snapshot.engine_version ~= schema.engine_version
        or type(snapshot.app_version) ~= "string"
        or #snapshot.app_version == 0
        or #snapshot.app_version > 64
        or snapshot.chip_unit_scale ~= 10
        or snapshot.starting_bankroll_units ~= 10000
        or snapshot.statistics_version ~= statistics.version
    then
        return false, "Unsupported save contract"
    end
    if snapshot.format_version >= 2 then
        local valid_training, training_error = training_statistics.validate(snapshot.training)
        if not valid_training then
            return false, training_error
        end
        local valid_settings, settings_error = validate_count_settings(snapshot.count_settings)
        if not valid_settings then
            return false, settings_error
        end
    end
    if snapshot.format_version == 3 then
        local valid_assistance, assistance_error = validate_assistance(snapshot.assistance)
        if not valid_assistance then
            return false, assistance_error
        end
        local valid_coach, coach_error = session_coach.validate(snapshot.coach)
        if not valid_coach then
            return false, coach_error
        end
    end
    for _, name in ipairs({ "profile_id", "lineage_id", "writer_device_id" }) do
        if not check.identifier(snapshot[name]) then
            return false, "Invalid local identity"
        end
    end
    if
        not check.integer(snapshot.revision, 1)
        or snapshot.parent_revision ~= snapshot.revision - 1
        or (snapshot.revision == 1 and snapshot.parent_snapshot_hash ~= "none")
        or (snapshot.revision > 1 and not check.hash(snapshot.parent_snapshot_hash))
    then
        return false, "Invalid revision ancestry"
    end
    for _, name in ipairs({ "created_at", "updated_at" }) do
        if type(snapshot[name]) ~= "string" or #snapshot[name] > 32 then
            return false, "Invalid timestamp metadata"
        end
    end
    local settings = snapshot.settings
    if
        not check.object(settings, { "sound_enabled", "volume", "reduced_motion" })
        or not check.boolean(settings.sound_enabled)
        or not check.boolean(settings.reduced_motion)
        or not check.integer(settings.volume, 0, 10)
    then
        return false, "Invalid settings"
    end
    local counters = snapshot.statistics
    if not check.object(counters, statistics.names) then
        return false, "Invalid statistics fields"
    end
    for _, name in ipairs(statistics.names) do
        if not check.integer(counters[name], name == "main_net_units" and -chips.maximum or 0) then
            return false, "Invalid bounded statistic: " .. name
        end
    end
    if
        counters.wins + counters.losses + counters.pushes ~= counters.settled_hands
        or counters.settled_hands < counters.completed_rounds
        or counters.settled_hands > counters.completed_rounds * 4
        or counters.natural_blackjacks > counters.completed_rounds
        or counters.player_busts > counters.losses
        or counters.main_returned_units - counters.main_staked_units ~= counters.main_net_units
    then
        return false, "Statistics relationships do not agree"
    end
    local valid_game, reason = game_validation.validate(snapshot.game)
    if not valid_game then
        return false, reason
    end
    local game = snapshot.game
    local active = game.phase == "player_turn"
    if
        counters.completed_rounds + counters.void_rounds
        ~= game.round_sequence - (active and 1 or 0)
    then
        return false, "Round completion counted twice or missing"
    end
    local escrow = 0
    if active then
        for _, player_hand in ipairs(game.round.hands) do
            escrow = escrow + player_hand.stake_units
        end
    end
    if
        game.bankroll_units
        ~= 10000 + counters.chip_grants_units + counters.main_net_units - escrow
    then
        return false, "Bankroll and lifetime ledger disagree"
    end
    return true
end

function schema.encode(snapshot, hash)
    local valid, reason = schema.validate(snapshot)
    if not valid then
        return nil, reason
    end
    local payload, payload_error = json.encode(snapshot)
    if not payload then
        return nil, payload_error
    end
    local checksum = hash(payload)
    local envelope, encode_error =
        json.encode({ checksum_algorithm = "sha256", checksum = checksum, payload = payload })
    return envelope, encode_error, checksum
end

function schema.decode(contents, hash)
    local envelope, error_message = json.decode(contents)
    if
        not check.object(envelope, { "checksum_algorithm", "checksum", "payload" })
        or envelope.checksum_algorithm ~= "sha256"
        or not check.hash(envelope.checksum)
        or type(envelope.payload) ~= "string"
    then
        return nil, error_message or "Invalid save envelope"
    end
    if hash(envelope.payload) ~= envelope.checksum then
        return nil, "Save checksum mismatch"
    end
    local snapshot, decode_error = json.decode(envelope.payload)
    if
        type(snapshot) == "table"
        and type(snapshot.format_version) == "number"
        and snapshot.format_version > schema.version
    then
        return nil, "Newer save version preserved; use its compatible app", "newer"
    end
    -- Return the original payload unchanged: ancestry hashes refer to its exact
    -- bytes. The session upgrades validated older versions in memory before use.
    if not snapshot then
        return nil, decode_error
    end
    local valid, reason = schema.validate(snapshot)
    if not valid then
        return nil, reason
    end
    return snapshot, nil, envelope.checksum
end

return schema
