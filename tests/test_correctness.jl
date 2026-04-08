# test_correctness.jl — Correctness tests for the CHARM algorithm
#
# Run with:  julia tests/test_correctness.jl
# or via:   julia --project=. tests/test_correctness.jl

using Test

# Load algorithm (path relative to repo root)
_REPO_ROOT = joinpath(@__DIR__, "..")
include(joinpath(_REPO_ROOT, "src", "algorithm", "charm.jl"))

# ─── Helper ──────────────────────────────────────────────────────────────────

"""Return the set of (sorted-items, support) pairs from a CharmResult."""
function result_set(r::CharmResult)
    return Set([(ci.items, ci.support) for ci in r.closed_itemsets])
end

# ─── Test suites ──────────────────────────────────────────────────────────────

@testset "CHARM correctness tests" begin

    # ── 1. Empty database ────────────────────────────────────────────────────
    @testset "empty database" begin
        r = charm(Vector{Vector{String}}(), 1)
        @test length(r) == 0
    end

    # ── 2. Single transaction ────────────────────────────────────────────────
    @testset "single transaction" begin
        txns = [["a", "b", "c"]]
        r = charm(txns, 1)
        # Every non-empty subset is frequent, but only the full set {a,b,c} is
        # closed (all subsets have the same tidset = {1}).
        @test length(r) == 1
        @test r.closed_itemsets[1].items == ["a", "b", "c"]
        @test r.closed_itemsets[1].support == 1
    end

    # ── 3. All identical transactions ───────────────────────────────────────
    @testset "identical transactions" begin
        txns = [["x", "y"], ["x", "y"], ["x", "y"]]
        r = charm(txns, 1)
        # Only {x, y} is closed (both x and y appear in all 3 transactions)
        items_list = [ci.items for ci in r.closed_itemsets]
        @test ["x", "y"] in items_list
        # Single items are subsumed by the pair (same tidset)
        @test !(["x"] in items_list)
        @test !(["y"] in items_list)
    end

    # ── 4. No frequent itemsets above threshold ──────────────────────────────
    @testset "min_support too high" begin
        txns = [["a", "b"], ["c", "d"], ["e", "f"]]
        r = charm(txns, 2)   # no item appears ≥2 times
        @test length(r) == 0
    end

    # ── 5. Classic CHARM paper example ──────────────────────────────────────
    @testset "classic example (10 transactions, 5 items)" begin
        #  TID | Items
        #  1   | a b c d e
        #  2   | a b c d
        #  3   | a b c e
        #  4   | a b d e
        #  5   | a c d e
        #  6   | b c d e
        #  7   | a b c
        #  8   | a b d
        #  9   | a c d
        #  10  | b c d
        txns = [
            ["a","b","c","d","e"],
            ["a","b","c","d"],
            ["a","b","c","e"],
            ["a","b","d","e"],
            ["a","c","d","e"],
            ["b","c","d","e"],
            ["a","b","c"],
            ["a","b","d"],
            ["a","c","d"],
            ["b","c","d"],
        ]

        r = charm(txns, 3)
        rs = result_set(r)

        # Ground-truth FCIs at min_sup=3 (verified by enumeration):
        expected = Set([
            (["a"],            8),
            (["b"],            8),
            (["c"],            8),
            (["d"],            8),
            (["e"],            5),
            (["a","b"],        6),
            (["a","c"],        6),
            (["a","d"],        6),
            (["a","e"],        4),
            (["b","c"],        6),
            (["b","d"],        6),
            (["b","e"],        4),
            (["c","d"],        6),
            (["c","e"],        4),
            (["d","e"],        4),
            (["a","b","c"],    4),
            (["a","b","d"],    4),
            (["a","b","e"],    3),
            (["a","c","d"],    4),
            (["a","c","e"],    3),
            (["a","d","e"],    3),
            (["b","c","d"],    4),
            (["b","c","e"],    3),
            (["b","d","e"],    3),
            (["c","d","e"],    3),
        ])

        for (items, sup) in expected
            @test (items, sup) in rs
        end

        # Every entry in the result must be a genuine closed frequent itemset
        for ci in r.closed_itemsets
            # Support must be correct
            actual_sup = count(t -> issubset(ci.items, t), txns)
            @test ci.support == actual_sup

            # Must be closed: no proper superset with same support
            for ci2 in r.closed_itemsets
                if ci.items != ci2.items && issubset(ci.items, ci2.items)
                    @test ci.support != ci2.support
                end
            end
        end
    end

    # ── 6. Fraction-based min_support ───────────────────────────────────────
    @testset "fractional min_support" begin
        txns = [["a","b"],["a","b"],["a","c"],["b","c"]]
        r_abs  = charm(txns, 2)
        r_frac = charm(txns, 0.5)   # 0.5 * 4 = 2
        @test result_set(r_abs) == result_set(r_frac)
    end

    # ── 7. Toy file round-trip ────────────────────────────────────────────────
    @testset "toy file round-trip" begin
        _REPO = joinpath(@__DIR__, "..")
        path = joinpath(_REPO, "data", "toy", "example1.dat")
        @test isfile(path)
        txns = read_transactions(path)
        @test length(txns) == 10
        r = charm(txns, 3)
        @test length(r) > 0
        # Support values must not exceed number of transactions
        @test all(ci.support <= length(txns) for ci in r.closed_itemsets)
    end

    # ── 8. Closedness property ───────────────────────────────────────────────
    @testset "closedness property" begin
        txns = [["a","b","c"],["a","b"],["a","c"],["b","c"],["a","b","c"]]
        r = charm(txns, 2)
        for ci in r.closed_itemsets
            # Check no proper superset in the result has the same support
            for ci2 in r.closed_itemsets
                if issubset(ci.items, ci2.items) && ci.items != ci2.items
                    @test ci.support > ci2.support
                end
            end
        end
    end

    # ── 9. Support monotonicity (Apriori property) ───────────────────────────
    @testset "support monotonicity" begin
        txns = [["a","b","c"],["a","b"],["a","c"],["b","c"],["a","b","c"]]
        r = charm(txns, 2)
        for ci in r.closed_itemsets
            for ci2 in r.closed_itemsets
                if issubset(ci.items, ci2.items)
                    @test ci.support >= ci2.support
                end
            end
        end
    end

end  # @testset

println("\nAll correctness tests passed ✓")
