using Test

_REPO_ROOT = joinpath(@__DIR__, "..")
include(joinpath(_REPO_ROOT, "src", "algorithm", "charm.jl"))

function as_dict(r::MiningResult)
    Dict(Tuple(fi.items) => fi.support for fi in r.itemsets)
end

@testset "Frequent itemset correctness vs SPMF references" begin
    datasets = [
        ("toy1", 2),
        ("toy2", 2),
        ("toy3", 2),
        ("toy4", 2),
        ("toy5", 2),
    ]

    for (name, minsup) in datasets
        path = joinpath(_REPO_ROOT, "data", "toy", "$(name).txt")
        ref = joinpath(_REPO_ROOT, "data", "reference", "spmf", "$(name)_minsup$(minsup).txt")

        @test isfile(path)
        @test isfile(ref)

        txns = read_spmf_transactions(path)
        reference = read_spmf_itemsets(ref)

        result_basic = charm(txns, minsup; output_mode=:all, implementation=:basic)
        result_opt   = charm(txns, minsup; output_mode=:all, implementation=:bitset)

        ratio_basic = exact_match_ratio(result_basic, reference)
        ratio_opt   = exact_match_ratio(result_opt, reference)

        @test ratio_basic == 1.0
        @test ratio_opt == 1.0

        @test as_dict(result_basic) == as_dict(result_opt)

        println("  $(name): match_basic=$(round(ratio_basic*100,digits=2))% match_opt=$(round(ratio_opt*100,digits=2))% itemsets=$(length(result_opt))")
    end
end

@testset "Closed-mode subset property" begin
    txns = read_spmf_transactions(joinpath(_REPO_ROOT, "data", "toy", "toy1.txt"))
    all_res = charm(txns, 2; output_mode=:all, implementation=:bitset)
    cls_res = charm(txns, 2; output_mode=:closed, implementation=:bitset)

    all_map = as_dict(all_res)
    cls_map = as_dict(cls_res)

    for (items, sup) in cls_map
        @test haskey(all_map, items)
        @test all_map[items] == sup
    end

    for fi in cls_res.itemsets
        for fj in cls_res.itemsets
            if length(fj.items) > length(fi.items) && fi.support == fj.support
                @test !all(in(fj.items), fi.items)
            end
        end
    end
end

println("\nAll correctness tests passed ✓")
