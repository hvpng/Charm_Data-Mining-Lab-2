# utils.jl — Utility functions for the CHARM algorithm

"""
    read_transactions(filepath; sep=" ", comment="#")

Read a transaction database from a text file.

Each non-comment line is one transaction; items are separated by `sep`.
Returns a `Vector{Vector{String}}`.

# Example file format (one transaction per line, items space-separated):
```
a b c d e
a b c d
a b c e
```
"""
function read_transactions(filepath::AbstractString; sep::String=" ", comment::String="#")::Vector{Vector{String}}
    transactions = Vector{Vector{String}}()
    open(filepath, "r") do f
        for line in eachline(f)
            line = strip(line)
            isempty(line) && continue
            startswith(line, comment) && continue
            items = filter(!isempty, split(line, sep))
            push!(transactions, String.(items))
        end
    end
    return transactions
end


"""
    resolve_min_support(min_support, n_transactions) -> Int

Convert a support threshold to an absolute count.
- If `min_support` is a `Float64` in (0, 1], treat it as a fraction.
- Otherwise treat it as an integer count.
"""
function resolve_min_support(min_support::Real, n_transactions::Int)::Int
    if min_support isa AbstractFloat && 0.0 < min_support <= 1.0
        return ceil(Int, min_support * n_transactions)
    end
    return Int(min_support)
end


"""
    build_tidsets(transactions) -> Dict{String, Set{Int}}

Scan the transaction database once to build the tidset for every item.
"""
function build_tidsets(transactions::Vector{<:AbstractVector})::Dict{String, Set{Int}}
    tidsets = Dict{String, Set{Int}}()
    for (tid, txn) in enumerate(transactions)
        for item in txn
            s = string(item)
            if !haskey(tidsets, s)
                tidsets[s] = Set{Int}()
            end
            push!(tidsets[s], tid)
        end
    end
    return tidsets
end


"""
    write_results(result::CharmResult, filepath::AbstractString)

Write the closed frequent itemsets to a plain-text file.
"""
function write_results(result::CharmResult, filepath::AbstractString)
    open(filepath, "w") do f
        println(f, "# CHARM output — $(length(result)) closed frequent itemsets")
        println(f, "# min_support = $(result.min_support) / $(result.n_transactions)")
        println(f, "# format: support\\titems...")
        for ci in sort(result.closed_itemsets; by=c -> (-c.support, c.items))
            println(f, "$(ci.support)\t$(join(ci.items, " "))")
        end
    end
end


"""
    print_results(result::CharmResult; io=stdout)

Pretty-print the closed frequent itemsets.
"""
function print_results(result::CharmResult; io::IO=stdout)
    println(io, "Found $(length(result)) frequent closed itemsets (min_support=$(result.min_support)):")
    for ci in sort(result.closed_itemsets; by=c -> (-c.support, c.items))
        println(io, "  {$(join(ci.items, ", "))}  support=$(ci.support)")
    end
end
