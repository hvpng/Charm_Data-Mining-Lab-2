using Test

_REPO_ROOT = joinpath(@__DIR__, "..")
include(joinpath(_REPO_ROOT, "src", "algorithm", "charm.jl"))

@testset "SPMF I/O roundtrip" begin
    in_path = joinpath(_REPO_ROOT, "data", "toy", "toy2.txt")
    out_path = joinpath(_REPO_ROOT, "results", "toy2_cli_test.txt")
    mkpath(dirname(out_path))

    txns = read_spmf_transactions(in_path)
    result = charm(txns, 2; implementation=:bitset)
    write_spmf_itemsets(result, out_path)

    @test isfile(out_path)
    parsed = read_spmf_itemsets(out_path)
    @test length(parsed) == length(result)
    @test exact_match_ratio(result, parsed) == 1.0
end

println("CLI/SPMF I/O test passed ✓")
