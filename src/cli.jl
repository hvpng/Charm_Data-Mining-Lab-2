include(joinpath(@__DIR__, "algorithm", "charm.jl"))

const USAGE = """
Usage:
  julia --project=. src/cli.jl --input <path> --output <path> --minsup <int|float> [--mode all|closed] [--impl basic|bitset]
"""

"""
    parse_args(args::Vector{String}) -> Dict{String, Union{Nothing, String}}

Parses CLI arguments for CHARM mining.

# Arguments
- `args::Vector{String}`: Raw command-line arguments.

# Returns
- `Dict`: Parsed option map containing `--input`, `--output`, `--minsup`, `--mode`, and `--impl`.

# Complexity
`O(n)` where `n` is number of CLI tokens.
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

"""
    parse_minsup(s::String) -> Real

Parses minimum support from CLI text.

# Arguments
- `s::String`: Support value as integer or decimal string.

# Returns
- `Int` for absolute support, or `Float64` for relative support.

# Complexity
`O(|s|)`.
"""
function parse_minsup(s::String)
    occursin(".", s) ? parse(Float64, s) : parse(Int, s)
end

"""
    main(args=ARGS)

CLI entrypoint: parses inputs, runs mining, and writes SPMF output.

# Arguments
- `args`: Command-line arguments (`ARGS` by default).

# Returns
Runs side effects (I/O and mining) and returns `nothing`.

# Complexity
Dominated by mining complexity in `charm`.
"""
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
