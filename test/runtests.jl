using Test

const REPO_ROOT = normpath(joinpath(@__DIR__, ".."))
const TEST_SCRIPTS = (
    joinpath(REPO_ROOT, "tests", "test_correctness.jl"),
    joinpath(REPO_ROOT, "tests", "test_benchmark.jl"),
    joinpath(REPO_ROOT, "tests", "test_cli.jl"),
)

for script in TEST_SCRIPTS
    @test isfile(script)
    include(script)
end
