--!strict

local passed = 0
local failed = 0
local Harness = {}

function Harness.equal(actual: any, expected: any)
	assert(actual == expected, "Expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

function Harness.test(name: string, run: () -> ())
	local ok, message = pcall(run)
	if ok then
		passed += 1
		print("PASS " .. name)
	else
		failed += 1
		print("FAIL " .. name .. ": " .. tostring(message))
	end
end

function Harness.finish()
	print(tostring(passed) .. " passed, " .. tostring(failed) .. " failed")
	assert(failed == 0, "Test suite failed")
end

return Harness
