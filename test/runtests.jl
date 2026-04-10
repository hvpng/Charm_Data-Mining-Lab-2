using Test

"""
    include_test_script(path::AbstractString)

Includes one test script file into the unified test run.

# Arguments
- `path::AbstractString`: Absolute path to test script.

# Returns
Includes the file for execution and returns `nothing`.

# Complexity
`O(1)` plus the included script runtime.
"""
function include_test_script(path::AbstractString)
    include(path)
end

const REPO_ROOT = normpath(joinpath(@__DIR__, ".."))
const TEST_SCRIPTS = (
    joinpath(REPO_ROOT, "tests", "test_correctness.jl"),
    joinpath(REPO_ROOT, "tests", "test_benchmark.jl"),
    joinpath(REPO_ROOT, "tests", "test_cli.jl"),
)

for script in TEST_SCRIPTS
    @test isfile(script)
    include_test_script(script)
end
