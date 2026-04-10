include(joinpath(@__DIR__, "..", "src", "algorithm", "charm.jl"))

using DelimitedFiles
using Random

const ROOT = normpath(joinpath(@__DIR__, ".."))
const OUTDIR = joinpath(ROOT, "results")
const EVAL_RANDOM_SEED = 20260410
mkpath(OUTDIR)

"""
    write_csv(path, header, rows)

Writes tabular rows to a CSV file.

# Arguments
- `path`: Destination file path.
- `header`: Iterable header columns.
- `rows`: Iterable row tuples/vectors.

# Returns
Creates or overwrites the target CSV file and returns `nothing`.

# Complexity
`O(r * c)` where `r` is row count and `c` average columns per row.
"""
function write_csv(path, header, rows)
    open(path, "w") do f
        println(f, join(header, ","))
        for row in rows
            println(f, join(row, ","))
        end
    end
end

"""
    run_correctness(dataset::String, minsup::Real)

Evaluates exact-match correctness ratio against SPMF reference output for one benchmark dataset.

# Arguments
- `dataset::String`: Dataset basename under `data/benchmark`.
- `minsup::Real`: Minimum support threshold.

# Returns
- `(dataset, minsup, ratio, n_itemsets)` tuple, or `nothing` if inputs are missing.

# Complexity
Dominated by mining complexity for the selected dataset.
"""
function run_correctness(dataset::String, minsup::Real)
    input = joinpath(ROOT, "data", "benchmark", "$(dataset).txt")
    ref = joinpath(ROOT, "data", "reference", "spmf", "$(dataset)_minsup$(minsup).txt")
    (isfile(input) && isfile(ref)) || return nothing

    txns = read_spmf_transactions(input)
    result = charm(txns, minsup; output_mode=:all, implementation=:bitset)
    ratio = exact_match_ratio(result, read_spmf_itemsets(ref))
    return (dataset, minsup, ratio, length(result))
end

"""
    run_runtime_curves(dataset::String, minsups)

Measures runtime of `:basic` and `:bitset` implementations across support thresholds.

# Arguments
- `dataset::String`: Dataset basename under `data/benchmark`.
- `minsups`: Iterable support thresholds.

# Returns
- `Vector`: Runtime rows `(dataset, minsup, basic_ms, bitset_ms, n_itemsets)`.

# Complexity
Dominated by repeated mining runs over `minsups`.
"""
function run_runtime_curves(dataset::String, minsups)
    input = joinpath(ROOT, "data", "benchmark", "$(dataset).txt")
    isfile(input) || return []

    txns = read_spmf_transactions(input)
    rows = Any[]
    for m in minsups
        basic = @timed charm(txns, m; output_mode=:all, implementation=:basic)
        opt = @timed charm(txns, m; output_mode=:all, implementation=:bitset)
        push!(rows, (dataset, m, basic.time * 1000, opt.time * 1000, length(opt.value)))
    end
    rows
end

"""
    run_scalability(dataset::String, minsup::Real)

Measures runtime scalability as transaction count increases.

# Arguments
- `dataset::String`: Dataset basename under `data/benchmark`.
- `minsup::Real`: Minimum support threshold.

# Returns
- `Vector`: Rows `(dataset, fraction, n_transactions, time_ms, n_itemsets)`.

# Complexity
Dominated by repeated mining runs over sampled dataset fractions.
"""
function run_scalability(dataset::String, minsup::Real)
    input = joinpath(ROOT, "data", "benchmark", "$(dataset).txt")
    isfile(input) || return []
    txns = read_spmf_transactions(input)
    rows = Any[]
    for frac in (0.10, 0.25, 0.50, 0.75, 1.00)
        n = max(1, floor(Int, frac * length(txns)))
        subset = txns[1:n]
        stats = @timed charm(subset, minsup; output_mode=:all, implementation=:bitset)
        push!(rows, (dataset, frac, n, stats.time * 1000, length(stats.value)))
    end
    rows
end

"""
    run_avglen_impact(; n_txn=5000, n_items=400, minsup=0.02)

Generates synthetic transactions with varying average length and measures runtime/memory impact.

# Arguments
- `n_txn`: Number of synthetic transactions.
- `n_items`: Item ID range upper bound.
- `minsup`: Minimum support threshold.

# Returns
- `Vector`: Rows `(avg_len, time_ms, n_itemsets, bytes)`.

# Complexity
Dominated by synthetic-data generation plus repeated mining runs.
"""
function run_avglen_impact(; n_txn=5000, n_items=400, minsup=0.02)
    rows = Any[]
    for avglen in (5, 10, 20, 30, 40)
        txns = [sort(unique(rand(1:n_items, avglen))) for _ in 1:n_txn]
        stats = @timed charm(txns, minsup; output_mode=:all, implementation=:bitset)
        push!(rows, (avglen, stats.time * 1000, length(stats.value), stats.bytes))
    end
    rows
end

"""
    main()

Evaluation entrypoint that writes all benchmark CSV reports under `results/`.

# Returns
Runs benchmark workflows with deterministic synthetic data generation and returns `nothing`.

# Complexity
Dominated by cumulative mining work across datasets and scenarios.
"""
function main()
    Random.seed!(EVAL_RANDOM_SEED)
    benchmark_dir = joinpath(ROOT, "data", "benchmark")
    benchmark_names = [splitext(f)[1] for f in readdir(benchmark_dir) if endswith(f, ".txt")]
    minsup_points = [0.10, 0.08, 0.06, 0.05, 0.04, 0.03, 0.02]

    correctness_rows = Any[]
    for d in benchmark_names
        x = run_correctness(d, 0.05)
        !isnothing(x) && push!(correctness_rows, x)
    end
    write_csv(joinpath(OUTDIR, "correctness.csv"),
              ["dataset", "minsup", "match_ratio", "n_itemsets"],
              correctness_rows)

    runtime_rows = Any[]
    for d in benchmark_names
        append!(runtime_rows, run_runtime_curves(d, minsup_points))
    end
    write_csv(joinpath(OUTDIR, "runtime_vs_minsup.csv"),
              ["dataset", "minsup", "time_basic_ms", "time_bitset_ms", "n_itemsets"],
              runtime_rows)

    mem_rows = Any[]
    for d in benchmark_names
        path = joinpath(ROOT, "data", "benchmark", "$(d).txt")
        isfile(path) || continue
        txns = read_spmf_transactions(path)
        b = @timed charm(txns, 0.05; output_mode=:all, implementation=:basic)
        o = @timed charm(txns, 0.05; output_mode=:all, implementation=:bitset)
        push!(mem_rows, (d, b.bytes, o.bytes, b.time * 1000, o.time * 1000))
    end
    write_csv(joinpath(OUTDIR, "memory_basic_vs_opt.csv"),
              ["dataset", "bytes_basic", "bytes_bitset", "time_basic_ms", "time_bitset_ms"],
              mem_rows)

    scale_dataset = "retail" in benchmark_names ? "retail" : ("accidents" in benchmark_names ? "accidents" : (isempty(benchmark_names) ? "" : first(benchmark_names)))
    scale_rows = run_scalability(scale_dataset, 0.05)
    write_csv(joinpath(OUTDIR, "scalability.csv"),
              ["dataset", "fraction", "n_transactions", "time_ms", "n_itemsets"],
              scale_rows)

    avglen_rows = run_avglen_impact()
    write_csv(joinpath(OUTDIR, "avglen_impact.csv"),
              ["avg_len", "time_ms", "n_itemsets", "bytes"],
              avglen_rows)

    println("Evaluation CSVs written to: $OUTDIR")
end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    main()
end
