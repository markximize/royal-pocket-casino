-- PURPOSE: Verify old save compatibility without inventing coaching observations.
-- CHANGE THIS MODULE WHEN: Format-3 fields or migration behavior changes.
-- DO NOT PUT HERE: Personal files, native durability claims or ledger shortcuts.

local test = require("tests.harness")
local copy = require("src.plain_copy")
local schema = require("src.persistence.save_schema")
local migrations = require("src.persistence.migrations")
local persistence = require("tests.persistence")
local coach = require("src.progress.session_coach")
local session = require("src.app.session")
local suite = {}

function suite.run(hash)
    if not hash then
        return
    end
    for _, version in ipairs({ 1, 2 }) do
        for _, active in ipairs({ false, true }) do
            test.test(
                "format "
                    .. version
                    .. (active and " active hand" or " betting")
                    .. " migrates without changing bankroll identity or old progress",
                function()
                    local current = persistence.fixture(hash, { "5", "10", "6", "9", "9" })
                    if active then
                        assert(session.command(current, "deal", { bet_units = 100 }))
                    end
                    local old = copy(current.snapshot)
                    old.format_version = version
                    old.app_version = version == 1 and "0.1.0-preview.1" or "0.1.0-preview.3"
                    old.assistance, old.coach = nil, nil
                    if version == 1 then
                        old.training, old.count_settings = nil, nil
                    end
                    assert(schema.validate(old))
                    local bytes = assert(schema.encode(old, hash))
                    local decoded, _, old_hash = schema.decode(bytes, hash)
                    test.same(decoded, old)
                    local migrated = migrations.to_current(decoded)
                    assert(schema.validate(migrated))
                    test.equal(migrated.format_version, 3)
                    test.same(migrated.game, old.game)
                    test.same(migrated.statistics, old.statistics)
                    test.same(migrated.settings, old.settings)
                    test.equal(migrated.profile_id, old.profile_id)
                    test.equal(migrated.lineage_id, old.lineage_id)
                    test.equal(migrated.revision, old.revision)
                    test.equal(migrated.parent_snapshot_hash, old.parent_snapshot_hash)
                    test.same(migrated.coach, coach.new())
                    test.equal(migrated.assistance.mode, "off")
                    if version == 2 then
                        test.same(migrated.training, old.training)
                        test.same(migrated.count_settings, old.count_settings)
                    end
                    test.same(migrations.to_current(migrated), migrated)
                    local decoded_again, _, hash_again = schema.decode(bytes, hash)
                    test.same(decoded_again, old)
                    test.equal(hash_again, old_hash)
                end
            )
        end
    end
    test.test("format 3 requires explicit assistance and bounded coach fields", function()
        local current = persistence.fixture(hash, { "A", "10", "K", "9" })
        local malformed = copy(current.snapshot)
        malformed.assistance = nil
        assert(not schema.validate(malformed))
        malformed = copy(current.snapshot)
        malformed.coach = nil
        assert(not schema.validate(malformed))
        malformed = copy(current.snapshot)
        malformed.assistance.mode = "autoplay"
        assert(not schema.validate(malformed))
        malformed = copy(current.snapshot)
        malformed.assistance.explanations = "true"
        assert(not schema.validate(malformed))
        malformed = copy(current.snapshot)
        malformed.coach.active.results.rounds = 1
        assert(not schema.validate(malformed))
    end)
    test.test(
        "old formats reject new assistance fields rather than accepting mixed contracts",
        function()
            local current = persistence.fixture(hash, { "A", "10", "K", "9" })
            local mixed = copy(current.snapshot)
            mixed.format_version = 2
            assert(not schema.validate(mixed))
        end
    )
    test.test("Assisted Play persists without changing a live bankroll or shoe", function()
        local current, storage = persistence.fixture(hash, { "5", "10", "6", "9", "9" })
        assert(session.command(current, "deal", { bet_units = 100 }))
        local before = copy(current.snapshot)
        local settings = {
            mode = "advanced",
            strategy_hints = false,
            explanations = true,
            deviations = true,
            check_count = true,
        }
        assert(session.assistance_settings(current, settings))
        local restored = session.open(storage)
        test.same(restored.snapshot.assistance, settings)
        test.same(restored.snapshot.game, before.game)
        test.same(restored.snapshot.statistics, before.statistics)
        test.same(restored.snapshot.coach, before.coach)
        settings.mode = "unknown"
        local files = copy(storage.files)
        assert(not session.assistance_settings(restored, settings))
        test.same(storage.files, files)
    end)
    test.test(
        "session closure is blocked in a live hand and preserves completed history",
        function()
            local current, storage = persistence.fixture(hash, { "5", "10", "6", "9", "9" })
            assert(session.command(current, "deal", { bet_units = 100 }))
            local before = copy(storage.files)
            assert(not session.new_coaching_session(current))
            test.same(storage.files, before)
            assert(session.command(current, "double"))
            assert(session.command(current, "next_round"))
            local bankroll = current.snapshot.game.bankroll_units
            assert(session.new_coaching_session(current))
            local restored = session.open(storage)
            test.equal(#restored.snapshot.coach.recent, 1)
            test.equal(restored.snapshot.coach.active.id, 2)
            test.equal(restored.snapshot.coach.recent[1].results.rounds, 1)
            test.equal(restored.snapshot.game.bankroll_units, bankroll)
        end
    )
    test.test("format 2 is preserved exactly before first format 3 preference save", function()
        local current, storage = persistence.fixture(hash, { "5", "10", "6", "9", "9" })
        assert(session.command(current, "deal", { bet_units = 100 }))
        assert(session.training_answer(current, "running", true))
        local old = copy(current.snapshot)
        old.format_version, old.app_version = 2, "0.1.0-preview.3"
        old.assistance, old.coach = nil, nil
        local source = assert(schema.encode(old, hash))
        storage.files["save_a.json"], storage.files["save_b.json"] = source, nil
        local restored = session.open(storage)
        test.equal(restored.migration_from, 2)
        assert(storage.files["backup_format_2.json"] == nil)
        test.same(restored.snapshot.coach, coach.new())
        local settings = copy(restored.snapshot.assistance)
        settings.mode = "basic"
        assert(session.assistance_settings(restored, settings))
        test.equal(storage.files["backup_format_2.json"], source)
        test.equal(storage.files["save_a.json"], source)
        test.same(restored.snapshot.game, old.game)
        test.same(restored.snapshot.statistics, old.statistics)
        test.same(restored.snapshot.training, old.training)
        test.equal(session.open(storage).snapshot.assistance.mode, "basic")
    end)
    test.test(
        "failed coaching save retries one answer without consuming normal bankroll",
        function()
            local current, storage = persistence.fixture(hash, { "5", "10", "6", "9", "9" })
            local before, write = copy(current.snapshot), storage.write
            storage.write = function()
                return false, "disk full"
            end
            assert(not session.training_answer(current, "strategy", false, "soft"))
            test.same(current.snapshot, before)
            assert(not session.training_answer(current, "strategy", false, "soft"))
            storage.write = write
            assert(session.retry(current))
            test.equal(current.snapshot.coach.active.practice.soft.attempts, 1)
            test.equal(current.snapshot.coach.active.practice.soft.correct, 0)
            test.same(current.snapshot.game, before.game)
            test.same(current.snapshot.statistics, before.statistics)
            test.equal(session.open(storage).snapshot.coach.active.practice.soft.attempts, 1)
        end
    )
end

return suite
