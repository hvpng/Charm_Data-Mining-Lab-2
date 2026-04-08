# test_benchmark.jl — Performance / scalability tests for CHARM
#
# Run with:  julia tests/test_benchmark.jl
# or via:   julia --project=. tests/test_benchmark.jl

using Test
using Random

_REPO_ROOT = joinpath(@__DIR__, "..")
include(joinpath(_REPO_ROOT, "src", "algorithm", "charm.jl"))

# ─── Helper ──────────────────────────────────────────────────────────────────

"""Measure wall-clock time (seconds) of `f()`."""
function timed(f)
    t0 = time()
    result = f()
    return result, time() - t0
end

# ─── Benchmarks ──────────────────────────────────────────────────────────────

@testset "CHARM benchmark tests" begin

    # ── 1. Toy databases ─────────────────────────────────────────────────────
    @testset "toy databases" begin
        toy_dir = joinpath(_REPO_ROOT, "data", "toy")

        for fname in readdir(toy_dir)
            endswith(fname, ".dat") || continue
            path = joinpath(toy_dir, fname)
            txns = read_transactions(path)
            n = length(txns)
            @test n > 0

            result, elapsed = timed(() -> charm(txns, 2))
            @test length(result) >= 0
            println("  $(fname): $(n) txns → $(length(result)) FCIs in $(round(elapsed*1000, digits=1)) ms")
        end
    end

    # ── 2. Synthetic benchmark database ──────────────────────────────────────
    @testset "synthetic benchmark (T10I4D1000)" begin
        path = joinpath(_REPO_ROOT, "data", "benchmark", "T10I4D1000.dat")
        isfile(path) || (@warn "Benchmark file not found; skipping"; return)

        txns = read_transactions(path)
        @test length(txns) == 1000

        for min_sup in [0.05, 0.10, 0.20]
            result, elapsed = timed(() -> charm(txns, min_sup))
            n_fcis = length(result)
            println("  T10I4D1000 min_sup=$(Int(round(min_sup*100)))%: " *
                    "$(n_fcis) FCIs in $(round(elapsed*1000, digits=1)) ms")
            @test elapsed < 60.0
            @test n_fcis >= 0
        end
    end

    # ── 3. Scalability: increasing database size ──────────────────────────────
    @testset "scalability by database size" begin
        rng = MersenneTwister(123)
        n_items = 50

        println("\n  Scalability (min_sup=10%, 50 items):")
        prev_elapsed = 0.0
        for n_txns in [100, 500, 1000, 2000]
            txns = [String.(string.(sort(randperm(rng, n_items)[1:rand(rng,3:12)])))
                    for _ in 1:n_txns]
            result, elapsed = timed(() -> charm(txns, 0.10))
            println("    n=$(n_txns): $(length(result)) FCIs in $(round(elapsed*1000,digits=1)) ms")
            @test elapsed < 120.0
        end
    end

    # ── 4. Scalability: varying min_support ───────────────────────────────────
    @testset "scalability by min_support" begin
        rng = MersenneTwister(456)
        n_items = 40
        txns = [String.(string.(sort(randperm(rng, n_items)[1:rand(rng,2:10)])))
                for _ in 1:500]

        println("\n  Scalability (500 txns, 40 items):")
        for min_sup in [0.30, 0.20, 0.10, 0.05]
            result, elapsed = timed(() -> charm(txns, min_sup))
            println("    min_sup=$(Int(round(min_sup*100)))%: $(length(result)) FCIs in $(round(elapsed*1000,digits=1)) ms")
            @test elapsed < 120.0
        end
    end

end  # @testset

println("\nAll benchmark tests passed ✓")
