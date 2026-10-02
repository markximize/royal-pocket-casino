-- PURPOSE: Verify trainer counters and the real version-1 to version-2 save path.
-- CHANGE THIS MODULE WHEN: Training persistence or migration behavior changes.
-- DO NOT PUT HERE: Personal saves, UI answers or hardware durability claims.

local test = require("tests.harness")
local copy = require("src.plain_copy")
local schema = require("src.persistence.save_schema")
local session = require("src.app.session")
local statistics = require("src.progress.training_statistics")
local migrations = require("src.persistence.migrations")
local persistence = require("tests.persistence")
local suite = {}

local function version_one_fixture(hash, ranks, active)
    local current, storage = persistence.fixture(hash, ranks)
    if active then
        assert(session.command(current, "deal", { bet_units = 100 }))
    end
    local old_snapshot = copy(current.snapshot)
    old_snapshot.format_version = 1
    old_snapshot.app_version = "0.1.0-preview.1"
    old_snapshot.training, old_snapshot.count_settings = nil, nil
    old_snapshot.assistance, old_snapshot.coach = nil, nil
    -- A single known-valid old generation is sufficient to exercise migration;
    -- its ancestry and revision remain the actual old-format values.
    storage.files["save_a.json"], storage.files["save_b.json"] = nil, nil
    storage.files["save_a.json"] = assert(schema.encode(old_snapshot, hash))
    return session.open(storage), storage, old_snapshot
end

local function check_normal_progress(actual, expected)
    test.same(actual.game, expected.game)
    test.same(actual.statistics, expected.statistics)
    test.same(actual.settings, expected.settings)
    test.equal(actual.profile_id, expected.profile_id)
    test.equal(actual.lineage_id, expected.lineage_id)
    test.equal(actual.created_at, expected.created_at)
end

function suite.run(hash)
    -- ## PURE COUNTER CONTRACT

    test.test(
        "strategy answers record accuracy counters and reset only the current streak",
        function()
            local training = statistics.new()
            training = assert(statistics.record(training, "strategy", true))
            training = assert(statistics.record(training, "strategy", true))
            training = assert(statistics.record(training, "strategy", false))
            test.same(training.strategy, {
                attempts = 3,
                correct = 2,
                incorrect = 1,
                streak = 0,
                best_streak = 2,
            })
            test.equal(training.counting.attempts, 0)
            assert(statistics.validate(training))
        end
    )
    test.test(
        "running and true-count answers share a streak but retain separate accuracy",
        function()
            local training = statistics.new()
            training = assert(statistics.record(training, "running", true))
            training = assert(statistics.record(training, "true_count", true))
            training = assert(statistics.record(training, "running", false))
            test.same(training.counting, {
                attempts = 3,
                running_attempts = 2,
                running_correct = 1,
                true_attempts = 1,
                true_correct = 1,
                streak = 0,
                best_streak = 2,
            })
            test.equal(training.strategy.attempts, 0)
            assert(statistics.validate(training))
        end
    )
    test.test(
        "training limits reject another answer without capping or mutating counters",
        function()
            local training = statistics.new()
            training.strategy = {
                attempts = 1000000000000,
                correct = 1000000000000,
                incorrect = 0,
                streak = 1000000000000,
                best_streak = 1000000000000,
            }
            local before = copy(training)
            assert(statistics.record(training, "strategy", true) == nil)
            assert(statistics.record(training, "unknown", true) == nil)
            assert(statistics.record(training, "running", "true") == nil)
            test.same(training, before)
        end
    )
    test.test("inconsistent, fractional and unbounded training counters fail validation", function()
        for _, corrupt in ipairs({
            function(training)
                training.strategy.attempts = 1
            end,
            function(training)
                training.strategy.correct = 0.5
            end,
            function(training)
                training.counting.running_correct = 1
            end,
            function(training)
                training.counting.streak = 1
            end,
            function(training)
                training.counting.attempts = 1000000000001
            end,
        }) do
            local training = statistics.new()
            corrupt(training)
            assert(not statistics.validate(training))
        end
    end)
    if not hash then
        return
    end

    -- ## SAVE MIGRATION AND TRAINING TRANSACTIONS

    for _, active in ipairs({ false, true }) do
        test.test(
            "version 1 "
                .. (active and "active hand" or "betting")
                .. " loads unchanged until a backed-up version 2 commit",
            function()
                local current, storage, old_snapshot =
                    version_one_fixture(hash, { "5", "10", "6", "9", "9" }, active)
                assert(current.snapshot, current.message)
                test.equal(current.snapshot.format_version, schema.version)
                test.equal(current.snapshot.revision, old_snapshot.revision)
                test.equal(current.saved.snapshot.format_version, 1)
                check_normal_progress(current.snapshot, old_snapshot)
                local original_bytes = storage.files["save_a.json"]
                local original_hash = current.saved.hash
                test.same(migrations.to_current(current.snapshot), current.snapshot)
                local resumed = session.open(storage)
                test.same(resumed.snapshot, current.snapshot)
                test.equal(storage.files["save_a.json"], original_bytes)
                assert(storage.files["backup_format_1.json"] == nil)
                assert(session.training_answer(current, "strategy", true), current.message)
                test.equal(current.snapshot.app_version, schema.app_version)
                test.equal(current.snapshot.revision, old_snapshot.revision + 1)
                test.equal(current.snapshot.parent_snapshot_hash, original_hash)
                check_normal_progress(current.snapshot, old_snapshot)
                test.equal(storage.files["backup_format_1.json"], original_bytes)
                test.equal(storage.files["save_a.json"], original_bytes)
                resumed = session.open(storage)
                test.same(resumed.snapshot, current.snapshot)
                test.equal(resumed.snapshot.training.strategy.correct, 1)
                assert(resumed.migration_from == nil)
            end
        )
    end
    test.test("failed migration backup preserves both normal progress and the v1 source", function()
        local current, storage, old_snapshot =
            version_one_fixture(hash, { "5", "10", "6", "9", "9" }, true)
        local before_files, before_snapshot = copy(storage.files), copy(current.snapshot)
        local real_write = storage.write
        storage.write = function()
            return false, "disk full"
        end
        assert(not session.training_answer(current, "running", true))
        test.same(storage.files, before_files)
        test.same(current.snapshot, before_snapshot)
        assert(current.pending)
        storage.write = real_write
        assert(session.retry(current), current.message)
        check_normal_progress(current.snapshot, old_snapshot)
        test.equal(current.snapshot.training.counting.running_correct, 1)
        assert(not session.retry(current))
        test.equal(session.open(storage).snapshot.training.counting.running_attempts, 1)
    end)
    test.test(
        "failed alternate-slot migration keeps its verified v1 backup and retries once",
        function()
            local current, storage, old_snapshot =
                version_one_fixture(hash, { "5", "10", "6", "9", "9" }, true)
            local source, real_write = storage.files["save_a.json"], storage.write
            storage.write = function(name, contents)
                if name == "save_b.json" then
                    return false, "disk full after backup"
                end
                return real_write(name, contents)
            end
            assert(not session.training_answer(current, "true_count", false))
            test.equal(storage.files["save_a.json"], source)
            test.equal(storage.files["backup_format_1.json"], source)
            check_normal_progress(current.snapshot, old_snapshot)
            test.equal(current.snapshot.training.counting.true_attempts, 0)
            storage.write = real_write
            assert(session.retry(current), current.message)
            test.equal(session.open(storage).snapshot.training.counting.true_attempts, 1)
            test.equal(storage.files["backup_format_1.json"], source)
        end
    )
    test.test("a different migration backup is preserved and blocks an unsafe overwrite", function()
        local current, storage = version_one_fixture(hash, { "A", "10", "K", "9" })
        local different_backup = copy(current.saved.snapshot)
        different_backup.settings.volume = 4
        storage.files["backup_format_1.json"] = assert(schema.encode(different_backup, hash))
        local before_files, before_snapshot = copy(storage.files), copy(current.snapshot)
        assert(not session.training_answer(current, "strategy", true))
        test.same(storage.files, before_files)
        test.same(current.snapshot, before_snapshot)
        assert(current.message:match("backup differs"))
    end)
    test.test("a torn migration backup is retained and safely repaired before retry", function()
        local current, storage = version_one_fixture(hash, { "5", "10", "6", "9", "9" }, true)
        local source, real_write = storage.files["save_a.json"], storage.write
        storage.write = function(name, contents)
            if name == "backup_format_1.json" then
                storage.files[name] = contents:sub(1, 20)
                return false, "torn backup write"
            end
            return real_write(name, contents)
        end
        assert(not session.training_answer(current, "running", true))
        local damaged_backup = storage.files["backup_format_1.json"]
        test.equal(storage.files["save_a.json"], source)
        storage.write = real_write
        assert(session.retry(current), current.message)
        test.equal(storage.files["backup_format_1.json"], source)
        test.equal(storage.files["recovery_backup_format_1.json"], damaged_backup)
        test.equal(current.snapshot.training.counting.running_correct, 1)
    end)
    test.test("an oversized migration backup is preserved without reading its bytes", function()
        local current, storage = version_one_fixture(hash, { "5", "10", "6", "9", "9" }, true)
        storage.files["backup_format_1.json"] = string.rep("x", 1048577)
        local before_files, before_snapshot = copy(storage.files), copy(current.snapshot)
        local real_read, backup_reads = storage.read, 0
        storage.read = function(name)
            if name == "backup_format_1.json" then
                backup_reads = backup_reads + 1
                error("Oversized migration backup must not be read")
            end
            return real_read(name)
        end
        assert(not session.training_answer(current, "running", true))
        test.equal(backup_reads, 0)
        test.same(storage.files, before_files)
        test.same(current.snapshot, before_snapshot)
        assert(current.message:match("Oversized migration backup"))
    end)
    test.test("a migration source enlarged after loading is rejected before reading it", function()
        local current, storage = version_one_fixture(hash, { "5", "10", "6", "9", "9" }, true)
        storage.files[current.saved.slot] = string.rep("x", 1048577)
        local before_files, before_snapshot = copy(storage.files), copy(current.snapshot)
        local source_reads = 0
        storage.read = function()
            source_reads = source_reads + 1
            error("An oversized migration source must not be read")
        end
        assert(not session.training_answer(current, "running", true))
        test.equal(source_reads, 0)
        test.same(storage.files, before_files)
        test.same(current.snapshot, before_snapshot)
        assert(current.message:match("Oversized migration source"))
    end)
    test.test(
        "a different migration recovery copy is preserved before repairing a backup",
        function()
            local current, storage = version_one_fixture(hash, { "A", "10", "K", "9" })
            storage.files["backup_format_1.json"] = "new damaged backup"
            storage.files["recovery_backup_format_1.json"] = "previous damage kept for diagnosis"
            local before_files, before_snapshot = copy(storage.files), copy(current.snapshot)
            assert(not session.training_answer(current, "running", true))
            test.same(storage.files, before_files)
            test.same(current.snapshot, before_snapshot)
            assert(current.message:match("recovery copy differs"))
        end
    )
    test.test(
        "an oversized migration recovery copy is preserved without reading its bytes",
        function()
            local current, storage = version_one_fixture(hash, { "A", "10", "K", "9" })
            storage.files["backup_format_1.json"] = "damaged backup"
            storage.files["recovery_backup_format_1.json"] = string.rep("x", 1048577)
            local before_files, before_snapshot = copy(storage.files), copy(current.snapshot)
            local real_read, recovery_reads = storage.read, 0
            storage.read = function(name)
                if name == "recovery_backup_format_1.json" then
                    recovery_reads = recovery_reads + 1
                    error("Oversized migration recovery copy must not be read")
                end
                return real_read(name)
            end
            assert(not session.training_answer(current, "running", true))
            test.equal(recovery_reads, 0)
            test.same(storage.files, before_files)
            test.same(current.snapshot, before_snapshot)
        end
    )
    test.test("invalid old saves are rejected before adding training defaults", function()
        local _, storage = version_one_fixture(hash, { "A", "10", "K", "9" })
        local source = storage.files["save_a.json"]
        storage.files["save_a.json"] = source:sub(1, #source - 20)
        local before = copy(storage.files)
        assert(session.open(storage).snapshot == nil)
        test.same(storage.files, before)
        assert(storage.files["backup_format_1.json"] == nil)
    end)
    test.test(
        "v2 trainer answers survive restart without changing an active normal hand",
        function()
            local current, storage = persistence.fixture(hash, { "5", "10", "6", "9", "9" })
            assert(session.command(current, "deal", { bet_units = 100 }))
            local before = copy(current.snapshot)
            assert(session.training_answer(current, "strategy", false))
            assert(session.training_answer(current, "running", true))
            assert(session.training_answer(current, "true_count", false))
            local resumed = session.open(storage)
            check_normal_progress(resumed.snapshot, before)
            test.equal(resumed.snapshot.training.strategy.incorrect, 1)
            test.equal(resumed.snapshot.training.counting.attempts, 2)
            test.equal(resumed.snapshot.training.counting.running_correct, 1)
            test.equal(resumed.snapshot.training.counting.true_correct, 0)
        end
    )
    test.test("count preferences are validated independently and do not change the shoe", function()
        local current, storage = persistence.fixture(hash, { "A", "10", "K", "9" })
        local before = copy(current.snapshot)
        local preferences = copy(current.snapshot.count_settings)
        preferences.show_running, preferences.show_true, preferences.show_decks = true, true, true
        preferences.level, preferences.pace, preferences.assistance = "advanced", "fast", false
        assert(session.count_settings(current, preferences))
        check_normal_progress(current.snapshot, before)
        test.same(session.open(storage).snapshot.count_settings, preferences)
        local files = copy(storage.files)
        preferences.deck_step = 0
        assert(not session.count_settings(current, preferences))
        assert(current.pending == nil)
        test.same(storage.files, files)
    end)
    test.test(
        "failed v2 answer retries the exact candidate once and preserves normal bankroll",
        function()
            local current, storage = persistence.fixture(hash, { "5", "10", "6", "9", "9" })
            local before, real_write = copy(current.snapshot), storage.write
            storage.write = function()
                return false, "disk full"
            end
            assert(not session.training_answer(current, "true_count", true))
            test.same(current.snapshot, before)
            assert(not session.training_answer(current, "true_count", true))
            storage.write = real_write
            assert(session.retry(current))
            test.equal(current.snapshot.training.counting.true_attempts, 1)
            test.equal(current.snapshot.training.counting.true_correct, 1)
            check_normal_progress(current.snapshot, before)
        end
    )
    test.test("corrupt v2 latest generation recovers complete earlier trainer counters", function()
        local current, storage = persistence.fixture(hash, { "A", "10", "K", "9" })
        assert(session.training_answer(current, "strategy", true))
        assert(session.training_answer(current, "running", true))
        local corrupt_slot = current.saved.slot
        storage.files[corrupt_slot] = "truncated v2"
        local recovered = session.open(storage)
        assert(recovered.message:match("Recovered"))
        test.equal(recovered.snapshot.training.strategy.correct, 1)
        test.equal(recovered.snapshot.training.counting.attempts, 0)
        assert(session.training_answer(recovered, "true_count", false))
        test.equal(storage.files["recovery_" .. corrupt_slot], "truncated v2")
        test.equal(recovered.snapshot.training.counting.true_attempts, 1)
    end)
    test.test(
        "malformed training fields and old-format extra fields are not silently defaulted",
        function()
            local current = persistence.fixture(hash, { "A", "10", "K", "9" })
            local malformed = copy(current.snapshot)
            malformed.training = nil
            assert(not schema.validate(malformed))
            malformed = copy(current.snapshot)
            malformed.format_version = 1
            assert(not schema.validate(malformed))
            malformed = copy(current.snapshot)
            malformed.count_settings.rounding = "floor"
            assert(not schema.validate(malformed))
        end
    )
end

return suite
