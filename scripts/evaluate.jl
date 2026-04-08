include(joinpath(@__DIR__, "..", "src", "algorithm", "charm.jl"))

using DelimitedFiles

const ROOT = normpath(joinpath(@__DIR__, ".."))
const OUTDIR = joinpath(ROOT, "results")
mkpath(OUTDIR)

function write_csv(path, header, rows)
    open(path, "w") do f
        println(f, join(header, ","))
        for row in rows
            println(f, join(row, ","))
        end
    end
end

function run_correctness(dataset::String, minsup::Real)
    input = joinpath(ROOT, "data", "benchmark", "$(dataset).txt")
    ref = joinpath(ROOT, "data", "reference", "spmf", "$(dataset)_minsup$(minsup).txt")
    (isfile(input) && isfile(ref)) || return nothing

    txns = read_spmf_transactions(input)
    result = charm(txns, minsup; output_mode=:all, implementation=:bitset)
    ratio = exact_match_ratio(result, read_spmf_itemsets(ref))
    return (dataset, minsup, ratio, length(result))
end

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

function run_avglen_impact(; n_txn=5000, n_items=400, minsup=0.02)
    rows = Any[]
    for avglen in (5, 10, 20, 30, 40)
        txns = [sort(unique(rand(1:n_items, avglen))) for _ in 1:n_txn]
        stats = @timed charm(txns, minsup; output_mode=:all, implementation=:bitset)
        push!(rows, (avglen, stats.time * 1000, length(stats.value), stats.bytes))
    end
    rows
end

function main()
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
