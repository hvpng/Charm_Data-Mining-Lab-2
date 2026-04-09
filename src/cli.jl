include(joinpath(@__DIR__, "algorithm", "charm.jl"))

const USAGE = """
Usage:
  julia --project=. src/cli.jl --input <path> --output <path> --minsup <int|float> [--mode all|closed] [--impl basic|bitset]
"""

function parse_args(args::Vector{String})
    if length(args) == 1 && args[1] in ("--help", "-h")
        println(USAGE)
        exit(0)
    end
    opts = Dict(
        "--input" => nothing,
        "--output" => nothing,
        "--minsup" => nothing,
        "--mode" => "all",
        "--impl" => "bitset",
    )
    i = 1
    while i <= length(args)
        key = args[i]
        haskey(opts, key) || error("Unknown argument: $key. Valid options are: --input, --output, --minsup, --mode, --impl\n$USAGE")
        i == length(args) && error("Missing value for $key")
        opts[key] = args[i + 1]
        i += 2
    end
    isnothing(opts["--input"]) && error("--input is required")
    isnothing(opts["--output"]) && error("--output is required")
    isnothing(opts["--minsup"]) && error("--minsup is required")
    return opts
end

function parse_minsup(s::String)
    occursin(".", s) ? parse(Float64, s) : parse(Int, s)
end

function main(args=ARGS)
    opts = parse_args(args)
    txns = read_spmf_transactions(opts["--input"])
    minsup = parse_minsup(opts["--minsup"])
    mode = Symbol(opts["--mode"])
    impl = Symbol(opts["--impl"])

    result = charm(txns, minsup; output_mode=mode, implementation=impl)
    write_spmf_itemsets(result, opts["--output"])
    println("Done. transactions=$(result.n_transactions), minsup=$(result.min_support), itemsets=$(length(result)), mode=$(mode), impl=$(impl)")
end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    main()
end
