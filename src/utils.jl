using DataStructures: OrderedDict

"""
    normalize_transactions(transactions::Vector{<:AbstractVector}) -> Vector{Vector{Int}}

Normalizes transactions by converting items to `Int`, removing duplicates, and sorting each transaction.

# Arguments
- `transactions::Vector{<:AbstractVector}`: Raw transaction collection.

# Returns
- `Vector{Vector{Int}}`: Canonicalized transactions.

# Complexity
For transaction `t` of length `k`, normalization is `O(k log k)` due to sorting; total is the sum over all transactions.
"""
function normalize_transactions(transactions::Vector{<:AbstractVector})::Vector{Vector{Int}}
    [sort(unique(Int.(t))) for t in transactions]
end

"""
    read_spmf_transactions(filepath::AbstractString) -> Vector{Vector{Int}}

Reads transactions in SPMF format from disk.

# Arguments
- `filepath::AbstractString`: Input file path with one transaction per line.

# Returns
- `Vector{Vector{Int}}`: Parsed transactions with sorted unique integer items.

# Complexity
`O(L + S)` where `L` is number of lines and `S` is total sorting/parsing work across lines.
"""
function read_spmf_transactions(filepath::AbstractString)::Vector{Vector{Int}}
    txns = Vector{Vector{Int}}()
    open(filepath, "r") do f
        for line in eachline(f)
            s = strip(line)
            isempty(s) && continue
            startswith(s, "#") && continue
            push!(txns, sort(unique(parse.(Int, split(s)))))
        end
    end
    txns
end

"""
    read_transactions(filepath::AbstractString; kwargs...) -> Vector{Vector{Int}}

Compatibility wrapper that delegates to `read_spmf_transactions`.

# Arguments
- `filepath::AbstractString`: Input file path.
- `kwargs...`: Unused keyword arguments kept for compatibility.

# Returns
- `Vector{Vector{Int}}`: Parsed transactions.

# Complexity
Same as `read_spmf_transactions`.
"""
read_transactions(filepath::AbstractString; kwargs...) = read_spmf_transactions(filepath)

"""
    resolve_min_support(min_support::Real, n_transactions::Int) -> Int

Converts absolute/relative minimum support into an absolute support count.

# Arguments
- `min_support::Real`: Minimum support as absolute (`>1`) or relative in `(0,1]`.
- `n_transactions::Int`: Total number of transactions.

# Returns
- `Int`: Effective absolute minimum support.

# Complexity
`O(1)`.
"""
function resolve_min_support(min_support::Real, n_transactions::Int)::Int
    min_support <= 0 && error("min_support must be > 0")
    if min_support isa AbstractFloat && min_support <= 1.0
        return max(1, ceil(Int, min_support * n_transactions))
    end
    return Int(min_support)
end

"""
    write_spmf_itemsets(result::MiningResult, filepath::AbstractString)

Writes mined itemsets to disk in SPMF output format.

# Arguments
- `result::MiningResult`: Mining output to serialize.
- `filepath::AbstractString`: Destination file path.

# Returns
Writes file contents and returns `nothing`.

# Complexity
`O(m log m + T)` where `m` is number of itemsets and `T` is total serialized item count.
"""
function write_spmf_itemsets(result::MiningResult, filepath::AbstractString)
    sorted_itemsets = sort(result.itemsets; by = fi -> (length(fi.items), fi.items, fi.support))
    open(filepath, "w") do f
        for fi in sorted_itemsets
            println(f, "$(join(fi.items, ' ')) #SUP: $(fi.support)")
        end
    end
end

"""
    print_results(result::MiningResult; io::IO=stdout)

Prints mined itemsets and metadata in a human-readable format.

# Arguments
- `result::MiningResult`: Mining output to display.
- `io::IO=stdout`: Destination stream.

# Returns
Writes formatted output and returns `nothing`.

# Complexity
`O(m log m)` for sorting `m` itemsets before printing.
"""
function print_results(result::MiningResult; io::IO=stdout)
    println(io, "Found $(length(result)) frequent itemsets (mode=$(result.output_mode), minsup=$(result.min_support))")
    for fi in sort(result.itemsets; by = x -> (-x.support, x.items))
        println(io, "  {$(join(fi.items, ", "))} support=$(fi.support)")
    end
end

"""
    read_spmf_itemsets(filepath::AbstractString) -> OrderedDict{Tuple{Vararg{Int}}, Int}

Reads SPMF-formatted frequent itemsets from disk.

# Arguments
- `filepath::AbstractString`: Input file path.

# Returns
- `OrderedDict{Tuple{Vararg{Int}}, Int}`: Mapping from itemset tuple to support count.

# Complexity
`O(L + P)` where `L` is number of lines and `P` is total parsing/sorting work.
"""
function read_spmf_itemsets(filepath::AbstractString)
    out = OrderedDict{Tuple{Vararg{Int}}, Int}()
    open(filepath, "r") do f
        for line in eachline(f)
            s = strip(line)
            isempty(s) && continue
            startswith(s, "#") && continue
            parts = split(s, "#SUP:")
            length(parts) == 2 || error("Invalid SPMF output line: $line")
            items = isempty(strip(parts[1])) ? Int[] : parse.(Int, split(strip(parts[1])))
            sup = parse(Int, strip(parts[2]))
            out[Tuple(sort(items))] = sup
        end
    end
    out
end

"""
    result_as_dict(result::MiningResult) -> OrderedDict{Tuple{Vararg{Int}}, Int}

Converts a `MiningResult` into a sorted dictionary representation.

# Arguments
- `result::MiningResult`: Mining output.

# Returns
- `OrderedDict{Tuple{Vararg{Int}}, Int}`: Sorted itemset-to-support mapping.

# Complexity
`O(m log m)` for sorting `m` itemsets.
"""
function result_as_dict(result::MiningResult)
    OrderedDict(Tuple(fi.items) => fi.support for fi in sort(result.itemsets; by = x -> (length(x.items), x.items, x.support)))
end

"""
    exact_match_ratio(result::MiningResult, reference::OrderedDict{Tuple{Vararg{Int}}, Int}) -> Float64

Computes exact support-match ratio between mined output and a reference mapping.

# Arguments
- `result::MiningResult`: Mined output to evaluate.
- `reference::OrderedDict{Tuple{Vararg{Int}}, Int}`: Ground-truth itemset supports.

# Returns
- `Float64`: Fraction of reference itemsets matched exactly.

# Complexity
`O(m log m + r)` where `m` is mined itemsets and `r` is reference itemsets.
"""
function exact_match_ratio(result::MiningResult, reference::OrderedDict{Tuple{Vararg{Int}}, Int})
    mine = result_as_dict(result)
    total = max(length(reference), 1)
    matched = count(kv -> haskey(mine, kv.first) && mine[kv.first] == kv.second, reference)
    matched / total
end
