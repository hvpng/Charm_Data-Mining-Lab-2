# structures.jl — Core data structures for the CHARM algorithm

"""
    Tidset

A transaction ID set: the set of transaction IDs that contain a given itemset.
Wraps a `Set{Int}` and caches its size for fast support lookups.
"""
struct Tidset
    tids::Set{Int}
    support::Int
    Tidset(tids::Set{Int}) = new(tids, length(tids))
end

Base.length(t::Tidset) = t.support
Base.:(==)(a::Tidset, b::Tidset) = a.tids == b.tids
Base.issubset(a::Tidset, b::Tidset) = issubset(a.tids, b.tids)
Base.intersect(a::Tidset, b::Tidset) = Tidset(intersect(a.tids, b.tids))
Base.show(io::IO, t::Tidset) = print(io, "Tidset(support=$(t.support), tids=$(t.tids))")


"""
    ItemsetNode

A node in the CHARM search tree, pairing an itemset with its tidset.

Fields:
- `items`   — the itemset (sorted `Vector{String}`)
- `tidset`  — the corresponding `Tidset`
"""
mutable struct ItemsetNode
    items::Vector{String}
    tidset::Tidset
end

ItemsetNode(items::Vector{String}, tids::Set{Int}) = ItemsetNode(sort(items), Tidset(tids))

support(node::ItemsetNode) = node.tidset.support

Base.show(io::IO, n::ItemsetNode) = 
    print(io, "ItemsetNode(items=$(n.items), support=$(support(n)))")


"""
    ClosedItemset

A confirmed frequent closed itemset with its support count.
"""
struct ClosedItemset
    items::Vector{String}
    support::Int
    tids::Set{Int}
end

ClosedItemset(node::ItemsetNode) = ClosedItemset(copy(node.items), support(node), copy(node.tidset.tids))

Base.show(io::IO, c::ClosedItemset) =
    print(io, "{$(join(c.items, ", "))} (support=$(c.support))")


"""
    CharmResult

Container for the output of the CHARM algorithm.

Fields:
- `closed_itemsets` — all discovered frequent closed itemsets
- `min_support`     — the minimum support threshold used
- `n_transactions`  — total number of transactions in the database
"""
struct CharmResult
    closed_itemsets::Vector{ClosedItemset}
    min_support::Int
    n_transactions::Int
end

Base.length(r::CharmResult) = length(r.closed_itemsets)

function Base.show(io::IO, r::CharmResult)
    println(io, "CharmResult:")
    println(io, "  min_support   = $(r.min_support) / $(r.n_transactions) transactions")
    println(io, "  closed sets   = $(length(r))")
    for ci in sort(r.closed_itemsets; by=c -> (c.support, c.items))
        println(io, "  ", ci)
    end
end
