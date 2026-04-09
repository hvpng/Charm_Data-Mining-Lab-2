struct FrequentItemset
    items::Vector{Int}
    support::Int
end

struct MiningResult
    itemsets::Vector{FrequentItemset}
    min_support::Int
    n_transactions::Int
    output_mode::Symbol   # :all or :closed
    implementation::Symbol # :basic or :bitset
end

Base.length(r::MiningResult) = length(r.itemsets)

function Base.show(io::IO, r::MiningResult)
    println(io, "MiningResult(mode=$(r.output_mode), impl=$(r.implementation))")
    println(io, "  min_support = $(r.min_support) / $(r.n_transactions)")
    println(io, "  itemsets    = $(length(r.itemsets))")
end
