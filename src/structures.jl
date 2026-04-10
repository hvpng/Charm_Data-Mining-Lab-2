"""
    FrequentItemset

Represents one frequent itemset mined from a transaction database.

# Fields
- `items::Vector{Int}`: Sorted list of item identifiers in the itemset.
- `support::Int`: Absolute support count (number of transactions containing `items`).

# Returns
Creates a `FrequentItemset` value.

# Complexity
Construction is `O(1)` assuming `items` is already prepared.
"""
struct FrequentItemset
    items::Vector{Int}
    support::Int
end

"""
    MiningResult

Container for frequent itemset mining outputs and run metadata.

# Fields
- `itemsets::Vector{FrequentItemset}`: Mined frequent itemsets.
- `min_support::Int`: Effective absolute minimum support used in mining.
- `n_transactions::Int`: Number of input transactions.
- `output_mode::Symbol`: Mining mode (`:all` or `:closed`).
- `implementation::Symbol`: Backend implementation (`:basic` or `:bitset`).

# Returns
Creates a `MiningResult` value.

# Complexity
Construction is `O(1)` excluding referenced vector contents.
"""
struct MiningResult
    itemsets::Vector{FrequentItemset}
    min_support::Int
    n_transactions::Int
    output_mode::Symbol   # :all or :closed
    implementation::Symbol # :basic or :bitset
end

"""
    Base.length(r::MiningResult) -> Int

Returns the number of mined itemsets in `r`.

# Arguments
- `r::MiningResult`: Mining result object.

# Returns
- `Int`: Number of itemsets in `r.itemsets`.

# Complexity
`O(1)`.
"""
Base.length(r::MiningResult) = length(r.itemsets)

"""
    Base.show(io::IO, r::MiningResult)

Pretty-prints a compact summary of a mining result.

# Arguments
- `io::IO`: Destination stream.
- `r::MiningResult`: Mining result object to display.

# Returns
Writes formatted text to `io` and returns `nothing`.

# Complexity
`O(1)`.
"""
function Base.show(io::IO, r::MiningResult)
    println(io, "MiningResult(mode=$(r.output_mode), impl=$(r.implementation))")
    println(io, "  min_support = $(r.min_support) / $(r.n_transactions)")
    println(io, "  itemsets    = $(length(r.itemsets))")
end
