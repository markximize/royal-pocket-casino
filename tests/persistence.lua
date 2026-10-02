-- PURPOSE: Verify resume, corruption recovery and uncertain-write reconciliation.
-- CHANGE THIS MODULE WHEN: The real save contract or a persistence bug changes.
-- DO NOT PUT HERE: Native durability claims or tests against personal saves.

local test = require("tests.harness")
local copy = require("src.plain_copy")
local fixtures = require("tests.fixtures")
local session = require("src.app.session")
local view = require("src.app.player_view")
local schema = require("src.persistence.save_schema")
local store = require("src.persistence.save_store")
local json = require("src.persistence.safe_json")
local persistence = {}

local function memory_storage(hash)
    local files, identities = {}, 0
    local storage = {
        files = files,
        device_id = string.rep("a", 32),
        hash = hash,
        now = function()
            return "2026-10-01T00:00:00Z"
        end,
        new_id = function()
            identities = identities + 1
            return string.format("%032x", identities)
        end,
        new_seed = function()
            return 12345
        end,
        size = function(name)
            return files[name] and #files[name]
        end,
        read = function(name)
            return files[name]
        end,
        write = function(name, contents)
            files[name] = contents
            return true
        end,
    }
    return storage
end

local function with_fixture(hash, ranks)
    local storage = memory_storage(hash)
    local current = session.open(storage)
    assert(current.snapshot, current.message)
    local candidate = copy(current.snapshot)
    candidate.game.shoe.order = fixtures.full_order(ranks, candidate.game.rules.deck_count)
    candidate.revision, candidate.parent_revision = 2, 1
    candidate.parent_snapshot_hash = current.saved.hash
    local saved, reason = store.commit(storage, current.saved, candidate)
    assert(saved, reason)
    current.saved, current.snapshot = saved, saved.snapshot
    return current, storage
end

persistence.fixture = with_fixture

function persistence.run(hash)
    test.test(
        "JSON preserves bounded chip integers and literal strings without executing them",
        function()
            local value = { 1000000000000, -1000000000000, 125, "os.execute('never')" }
            test.same(assert(json.decode(assert(json.encode(value)))), value)
            assert(json.decode(string.rep("[", 33) .. string.rep("]", 33)) == nil)
            assert(json.decode(string.rep("x", 1048577)) == nil)
        end
    )
    test.test("resume an active hand with the same hidden hole and next card", function()
        local current, storage = with_fixture(hash, { "5", "10", "6", "9", "9" })
        assert(session.command(current, "deal", { bet_units = 100 }))
        local visible = view.build(current)
        assert(visible.dealer.cards[2].hidden and visible.dealer.cards[2].id == nil)
        assert(visible.dealer.total == nil and visible.remaining_cards == 308)
        local resumed = session.open(storage)
        test.same(resumed.snapshot.game, current.snapshot.game)
        assert(session.command(resumed, "double"))
        test.equal(resumed.snapshot.game.bankroll_units, 10200)
        test.equal(resumed.snapshot.statistics.completed_rounds, 1)
        test.equal(resumed.snapshot.statistics.double_actions, 1)
        resumed = session.open(storage)
        assert(session.command(resumed, "next_round"))
        test.equal(resumed.snapshot.game.bankroll_units, 10200)
        test.equal(resumed.snapshot.statistics.completed_rounds, 1)
    end)
    test.test("resume split progression without predealing or double-counting wagers", function()
        local current, storage = with_fixture(hash, { "8", "10", "8", "7", "10", "9" })
        assert(session.command(current, "deal", { bet_units = 100 }))
        assert(session.command(current, "split"))
        current = session.open(storage)
        test.equal(#current.snapshot.game.round.hands[2].cards, 1)
        assert(session.command(current, "stand"))
        current = session.open(storage)
        test.equal(current.snapshot.game.round.active_hand, 2)
        assert(session.command(current, "stand"))
        test.equal(current.snapshot.game.bankroll_units, 10100)
        test.equal(current.snapshot.statistics.settled_hands, 2)
        test.equal(current.snapshot.statistics.main_staked_units, 200)
        test.equal(current.snapshot.statistics.main_returned_units, 300)
    end)
    test.test("a rejected action never changes a save revision", function()
        local current, storage = with_fixture(hash, { "K", "10", "Q", "7" })
        assert(session.command(current, "deal", { bet_units = 100 }))
        local before = copy(storage.files)
        assert(not session.command(current, "split"))
        test.same(storage.files, before)
    end)
    test.test("malformed bets and settings are rejected without blocking later play", function()
        local current, storage = with_fixture(hash, { "5", "10", "6", "9", "9" })
        local before = copy(storage.files)
        assert(not session.command(current, "deal"))
        assert(not session.command(current, "deal", { bet_units = "100" }))
        assert(not session.settings(current, { volume = 99 }))
        assert(current.pending == nil)
        test.same(storage.files, before)
        assert(session.command(current, "deal", { bet_units = 100 }))
    end)
    for _, failure in ipairs({ "before", "torn", "after", "readback" }) do
        test.test(
            "save failure " .. failure .. " keeps one complete snapshot and retries once",
            function()
                local current, storage = with_fixture(hash, { "A", "10", "K", "9" })
                local real_write, real_read = storage.write, storage.read
                local original = copy(current.snapshot)
                local failed_read_name
                storage.write = function(name, contents)
                    if failure == "before" then
                        return false, "simulated disk full"
                    end
                    if failure == "torn" then
                        storage.files[name] = contents:sub(1, 20)
                        return false, "torn write"
                    end
                    local written = real_write(name, contents)
                    if failure == "readback" then
                        failed_read_name = name
                    end
                    return failure ~= "after" and written, "uncertain acknowledgement"
                end
                storage.read = function(name)
                    if name == failed_read_name then
                        return nil, "simulated readback failure"
                    end
                    return real_read(name)
                end
                local accepted = session.command(current, "deal", { bet_units = 100 })
                if failure == "after" then
                    assert(accepted)
                else
                    assert(not accepted and current.pending)
                    test.same(current.snapshot, original)
                    assert(not session.command(current, "deal", { bet_units = 100 }))
                    storage.write, storage.read = real_write, real_read
                    assert(session.retry(current), current.message)
                end
                test.equal(current.snapshot.game.bankroll_units, 10150)
                test.equal(current.snapshot.statistics.completed_rounds, 1)
                local resumed = session.open(storage)
                test.equal(resumed.snapshot.game.bankroll_units, 10150)
                test.equal(resumed.snapshot.statistics.completed_rounds, 1)
            end
        )
    end
    test.test(
        "corrupt latest slot visibly rolls back and preserves bytes before replacement",
        function()
            local current, storage = with_fixture(hash, { "5", "10", "6", "9", "9" })
            assert(session.command(current, "deal", { bet_units = 100 }))
            local corrupt_slot = current.saved.slot
            storage.files[corrupt_slot] = "damaged slot"
            current = session.open(storage)
            assert(current.message:match("Recovered"))
            test.equal(current.snapshot.game.phase, "betting")
            assert(session.command(current, "deal", { bet_units = 100 }))
            test.equal(storage.files["recovery_" .. corrupt_slot], "damaged slot")
        end
    )
    test.test("two corrupt saves are preserved and do not silently grant a new bankroll", function()
        local storage = memory_storage(hash)
        storage.files["save_a.json"], storage.files["save_b.json"] = "bad a", "bad b"
        local current = session.open(storage)
        assert(current.snapshot == nil)
        test.equal(storage.files["save_a.json"], "bad a")
        test.equal(storage.files["save_b.json"], "bad b")
    end)
    test.test("newer schemas and older unsupported schemas are not silently migrated", function()
        local current, storage = with_fixture(hash, { "A", "10", "K", "9" })
        local future = copy(current.snapshot)
        future.format_version = schema.version + 1
        local payload = assert(json.encode(future))
        storage.files["save_a.json"] = assert(json.encode({
            checksum_algorithm = "sha256",
            checksum = hash(payload),
            payload = payload,
        }))
        local before = copy(storage.files)
        assert(session.open(storage).snapshot == nil)
        test.same(storage.files, before)
        future.format_version = 0
        assert(not schema.validate(future))
    end)
    test.test("same-revision conflicts and unrelated identities stop play", function()
        local current, storage = with_fixture(hash, { "A", "10", "K", "9" })
        local conflict = copy(current.snapshot)
        conflict.settings.volume = 4
        storage.files["save_a.json"] = assert(schema.encode(conflict, hash))
        assert(session.open(storage).snapshot == nil)
        conflict.profile_id = string.rep("b", 32)
        storage.files["save_a.json"] = assert(schema.encode(conflict, hash))
        assert(session.open(storage).snapshot == nil)
    end)
    test.test(
        "invalid cards, escrow, stats and result types fail validation rather than crashing",
        function()
            local current = with_fixture(hash, { "5", "10", "6", "9", "9" })
            assert(session.command(current, "deal", { bet_units = 100 }))
            local duplicate = copy(current.snapshot)
            duplicate.game.shoe.order[2] = duplicate.game.shoe.order[1]
            assert(not schema.validate(duplicate))
            local wrong_wallet = copy(current.snapshot)
            wrong_wallet.game.bankroll_units = 1
            assert(not schema.validate(wrong_wallet))
            local wrong_stats = copy(current.snapshot)
            wrong_stats.statistics.completed_rounds = 1
            assert(not schema.validate(wrong_stats))
            assert(session.command(current, "stand"))
            local wrong_result = copy(current.snapshot)
            wrong_result.game.round.result = true
            assert(not schema.validate(wrong_result))
            local unsupported = copy(current.snapshot)
            unsupported.game.rng.version = 99
            assert(not schema.validate(unsupported))
        end
    )
    test.test("bad checksum is rejected before gameplay decoding", function()
        local current = with_fixture(hash, { "A", "10", "K", "9" })
        local envelope = assert(json.decode(assert(schema.encode(current.snapshot, hash))))
        envelope.payload = envelope.payload .. " "
        assert(schema.decode(assert(json.encode(envelope)), hash) == nil)
    end)
    test.test("a settled soft 17 cannot be reinterpreted using hits-soft-17 rules", function()
        local current = with_fixture(hash, { "10", "A", "8", "6", "2" })
        assert(session.command(current, "deal", { bet_units = 100 }))
        assert(session.command(current, "stand"))
        local changed = copy(current.snapshot)
        changed.game.rules.dealer_hits_soft_17 = true
        assert(not schema.validate(changed))
    end)
    test.test("a saved split-ace flag cannot make an eight an ace", function()
        local current = with_fixture(hash, { "8", "10", "8", "7", "10", "9" })
        assert(session.command(current, "deal", { bet_units = 100 }))
        assert(session.command(current, "split"))
        assert(session.command(current, "stand"))
        assert(session.command(current, "stand"))
        local changed = copy(current.snapshot)
        changed.game.round.hands[1].split_aces = true
        assert(not schema.validate(changed))
    end)
    test.test("save changed by another open instance is not overwritten", function()
        local current, storage = with_fixture(hash, { "5", "10", "6", "9", "9" })
        local other = session.open(storage)
        assert(session.command(current, "deal", { bet_units = 100 }))
        local before = copy(storage.files)
        assert(not session.command(other, "deal", { bet_units = 100 }))
        test.same(storage.files, before)
    end)
    test.test(
        "settings and rule changes retain statistics and only change rules between rounds",
        function()
            local current = with_fixture(hash, { "5", "10", "6", "9", "9" })
            local settings = copy(current.snapshot.settings)
            settings.reduced_motion = true
            assert(session.settings(current, settings))
            local preset = copy(current.snapshot.game.rules)
            preset.deck_count = 8
            assert(session.command(current, "configure", { rules = preset }))
            test.equal(#current.snapshot.game.shoe.order, 416)
            assert(session.command(current, "deal", { bet_units = 100 }))
            assert(not session.command(current, "configure", { rules = preset }))
            test.equal(
                current.snapshot.statistics.main_net_units,
                current.snapshot.game.bankroll_units
                    - 10000
                    + (current.snapshot.game.phase == "player_turn" and 100 or 0)
            )
        end
    )
    test.test("app version is informational when engine/schema remain compatible", function()
        local current = with_fixture(hash, { "A", "10", "K", "9" })
        local compatible = copy(current.snapshot)
        compatible.app_version = "older-preview"
        assert(schema.validate(compatible))
    end)
end

return persistence
