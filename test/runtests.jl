using Test
using Random

"""
    TEST_SEED -> Int

Fixed RNG seed used by the test suite to guarantee reproducible behavior
across runs.
"""
const TEST_SEED = 20260412
Random.seed!(TEST_SEED)

"""
    REPO_ROOT -> String

Absolute path to the repository root, inferred from the location of this file.
"""
const REPO_ROOT = normpath(joinpath(@__DIR__, ".."))

"""
    DATA -> String

Absolute path to the top-level data directory (`data/` relative to the
repository root). Defined here so all test scripts can share it without
redefinition conflicts.
"""
const DATA = joinpath(REPO_ROOT, "data")

"""
    REF -> String

Absolute path to the SPMF ground-truth reference directory
(`data/reference/spmf/` relative to the repository root).
"""
const REF = joinpath(REPO_ROOT, "data", "reference", "spmf")

"""
    BENCH -> String

Absolute path to the benchmark dataset directory (`data/benchmark/` relative
to the repository root).
"""
const BENCH = joinpath(REPO_ROOT, "data", "benchmark")

"""
    TEST_SCRIPTS -> Tuple{String, ...}

Ordered list of test script paths to execute. Scripts are run in order:
correctness first, then benchmark, then CLI.
"""
const TEST_SCRIPTS = (
    joinpath(REPO_ROOT, "tests", "test_correctness.jl"),
    joinpath(REPO_ROOT, "tests", "test_benchmark.jl"),
    joinpath(REPO_ROOT, "tests", "test_cli.jl"),
)

for script in TEST_SCRIPTS
    @test isfile(script)
    include(script)
end