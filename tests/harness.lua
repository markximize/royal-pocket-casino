-- PURPOSE: Run readable scenario assertions without a test-framework dependency.
-- CHANGE THIS MODULE WHEN: Test reporting or equality diagnostics change.
-- DO NOT PUT HERE: Expected Blackjack payouts or production behavior.

local harness = { passed = 0, failed = 0 }

function harness.equal(actual, expected, context)
    assert(
        actual == expected,
        (context or "Value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual)
    )
end

function harness.same(actual, expected)
    harness.equal(type(actual), type(expected), "Type")
    if type(actual) ~= "table" then
        harness.equal(actual, expected)
        return
    end
    for name, value in pairs(expected) do
        harness.same(actual[name], value)
    end
    for name in pairs(actual) do
        assert(expected[name] ~= nil, "Unexpected field " .. tostring(name))
    end
end

function harness.test(name, scenario)
    local passed, error_message = pcall(scenario)
    if passed then
        harness.passed = harness.passed + 1
    else
        harness.failed = harness.failed + 1
        print("FAIL " .. name .. ": " .. tostring(error_message))
    end
end

function harness.finish()
    print(string.format("Scenarios: %d passed, %d failed", harness.passed, harness.failed))
    assert(harness.failed == 0, "Blackjack preview tests failed")
end

return harness
