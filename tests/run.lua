-- PURPOSE: Compose the approved preview checks under the actual Lua runtime.
-- CHANGE THIS MODULE WHEN: Required scenario suites change.
-- DO NOT PUT HERE: Hardware claims or production startup.

local run = {}

function run.all(hash)
    require("tests.unit").run()
    require("tests.unit").rule_matrix()
    require("tests.counting").run()
    require("tests.audio").run()
    require("tests.tutorial").run()
    require("tests.deviations").run()
    require("tests.targeted_practice").run()
    require("tests.coaching").run()
    require("tests.coach_migration").run(hash)
    require("tests.polish").run(hash)
    require("tests.distribution").run()
    require("tests.strategy").run()
    require("tests.training_persistence").run(hash)
    require("tests.training").run(hash)
    if hash then
        require("tests.persistence").run(hash)
        require("tests.presentation").run(hash)
    end
    require("tests.simulation").run()
    require("tests.harness").finish()
end

return run
