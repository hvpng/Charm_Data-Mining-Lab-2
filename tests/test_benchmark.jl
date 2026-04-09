using Test

_REPO_ROOT = joinpath(@__DIR__, "..")
include(joinpath(_REPO_ROOT, "src", "algorithm", "charm.jl"))

function timed_run(f)
    t0 = time()
    result = f()
    elapsed_ms = (time() - t0) * 1000
    return result, elapsed_ms
end

@testset "Benchmark + optimization comparison" begin
    path = joinpath(_REPO_ROOT, "data", "benchmark", "T10I4D1000.dat")
    @test isfile(path)
    txns = read_spmf_transactions(path)
    @test length(txns) == 1000

    println("\nRuntime vs minsup (basic vs bitset)")
    for minsup in [0.20, 0.15, 0.10, 0.08, 0.05]
        rb, tb = timed_run(() -> charm(txns, minsup; output_mode=:all, implementation=:basic))
        ro, to = timed_run(() -> charm(txns, minsup; output_mode=:all, implementation=:bitset))

        @test Dict(Tuple(fi.items)=>fi.support for fi in rb.itemsets) == Dict(Tuple(fi.items)=>fi.support for fi in ro.itemsets)
        @test tb > 0.0
        @test to > 0.0

        speedup = tb / to
        println("  minsup=$(Int(round(minsup*100)))% basic=$(round(tb,digits=2))ms bitset=$(round(to,digits=2))ms speedup=$(round(speedup,digits=2))x itemsets=$(length(ro))")
    end

    # Peak memory comparison at medium minsup
    minsup = 0.10
    stats_basic = @timed charm(txns, minsup; output_mode=:all, implementation=:basic)
    stats_opt   = @timed charm(txns, minsup; output_mode=:all, implementation=:bitset)

    @test stats_basic.time > 0
    @test stats_opt.time > 0
    @test stats_basic.bytes > 0
    @test stats_opt.bytes > 0

    println("\nMemory at minsup=10%: basic=$(round(stats_basic.bytes/1024^2,digits=2)) MiB, bitset=$(round(stats_opt.bytes/1024^2,digits=2)) MiB")
end

println("\nAll benchmark tests passed ✓")
