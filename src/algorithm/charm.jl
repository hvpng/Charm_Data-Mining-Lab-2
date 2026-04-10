include(joinpath(@__DIR__, "..", "structures.jl"))
include(joinpath(@__DIR__, "..", "utils.jl"))

using DataStructures: DefaultDict

"""
    support(t::Set{Int}) -> Int
    support(t::BitVector) -> Int

Returns the support count (cardinality) of a tidset.

# Arguments
- `t`: Tidset represented as `Set{Int}` or `BitVector`.

# Returns
- `Int`: Number of transaction IDs present in `t`.

# Complexity
`Set{Int}`: `O(1)` amortized for stored length.  
`BitVector`: `O(n)` over vector length.
"""
support(t::Set{Int}) = length(t)
support(t::BitVector) = count(t)

"""
    intersect_tidset(a, b)

Computes tidset intersection for the active tidset representation.

# Arguments
- `a`, `b`: Tidsets with the same representation (`Set{Int}` or `BitVector`).

# Returns
- Intersection tidset with matching representation.

# Complexity
`O(min(|a|, |b|))` for sets, `O(n)` for bitvectors.
"""
intersect_tidset(a::Set{Int}, b::Set{Int}) = intersect(a, b)
intersect_tidset(a::BitVector, b::BitVector) = a .& b

"""
    tidset_equal(a, b) -> Bool

Checks whether two tidsets are equal.

# Arguments
- `a`, `b`: Tidsets of the same representation.

# Returns
- `Bool`: `true` when both tidsets contain identical transaction IDs.

# Complexity
Set: `O(min(|a|, |b|))`; bitvector: `O(n)`.
"""
tidset_equal(a::Set{Int}, b::Set{Int}) = a == b
tidset_equal(a::BitVector, b::BitVector) = a == b

"""
    tidset_subseteq(a, b) -> Bool

Checks whether tidset `a` is a subset of tidset `b`.

# Arguments
- `a`, `b`: Tidsets of the same representation.

# Returns
- `Bool`: `true` if every transaction in `a` also appears in `b`.

# Complexity
Set: `O(|a|)` average; bitvector: `O(n)`.
"""
tidset_subseteq(a::Set{Int}, b::Set{Int}) = issubset(a, b)
tidset_subseteq(a::BitVector, b::BitVector) = !any(a .& .!b)

"""
    tidset_proper_subset(a, b) -> Bool

Checks whether `a` is a strict subset of `b`.

# Arguments
- `a`, `b`: Tidsets of the same representation.

# Returns
- `Bool`: `true` iff `a ⊊ b`.

# Complexity
Delegates to subset/equality checks; same asymptotic bounds.
"""
tidset_proper_subset(a, b) = tidset_subseteq(a, b) && !tidset_equal(a, b)

"""
    tidset_proper_superset(a, b) -> Bool

Checks whether `a` is a strict superset of `b`.

# Arguments
- `a`, `b`: Tidsets of the same representation.

# Returns
- `Bool`: `true` iff `a ⊋ b`.

# Complexity
Delegates to subset/equality checks; same asymptotic bounds.
"""
tidset_proper_superset(a, b) = tidset_subseteq(b, a) && !tidset_equal(a, b)

"""
    union_items(a::Vector{Int}, b::Vector{Int}) -> Vector{Int}

Builds a sorted unique union of two item vectors.

# Arguments
- `a::Vector{Int}`: First item vector.
- `b::Vector{Int}`: Second item vector.

# Returns
- `Vector{Int}`: Sorted unique item union.

# Complexity
`O((|a|+|b|) log(|a|+|b|))`.
"""
union_items(a::Vector{Int}, b::Vector{Int}) = sort(unique(vcat(a, b)))

"""
    _build_vertical_basic(transactions::Vector{Vector{Int}}) -> Dict{Int, Set{Int}}

Builds a vertical database where each item maps to a `Set` of transaction IDs.

# Arguments
- `transactions::Vector{Vector{Int}}`: Normalized transactions.

# Returns
- `Dict{Int, Set{Int}}`: Item-to-tidset mapping.

# Complexity
`O(N)` average where `N` is total number of item occurrences.
"""
function _build_vertical_basic(transactions::Vector{Vector{Int}})
    tidsets = DefaultDict{Int, Set{Int}}(() -> Set{Int}())
    for (tid, txn) in enumerate(transactions)
        for item in txn
            push!(tidsets[item], tid)
        end
    end
    Dict(tidsets)
end

"""
    _build_vertical_bitset(transactions::Vector{Vector{Int}}) -> Dict{Int, BitVector}

Builds a vertical database where each item maps to a bitvector tidset.

# Arguments
- `transactions::Vector{Vector{Int}}`: Normalized transactions.

# Returns
- `Dict{Int, BitVector}`: Item-to-bitset mapping over all transactions.

# Complexity
`O(N + U*T)` where `N` is total item occurrences, `U` number of distinct items, and `T` number of transactions.
"""
function _build_vertical_bitset(transactions::Vector{Vector{Int}})
    n = length(transactions)
    items = sort(unique(vcat(transactions...)))
    tidsets = Dict{Int, BitVector}(item => falses(n) for item in items)
    for (tid, txn) in enumerate(transactions)
        for item in txn
            # Safe: tid ∈ 1:n from enumerate(transactions), and each bitvector has length n.
            @inbounds tidsets[item][tid] = true
        end
    end
    tidsets
end

"""
    _replace_all_with_union!(P, xi, x)

Replaces candidates in `P` containing all items in `xi` by their union with `x`.

# Arguments
- `P::Vector{Tuple{Vector{Int}, T}}`: Candidate list to mutate.
- `xi::Vector{Int}`: Itemset pattern to match as subset.
- `x::Vector{Int}`: Itemset to union into matched candidates.

# Returns
Mutates `P` in-place and returns `nothing`.

# Complexity
`O(|P| * k)` where `k` is subset-check cost over candidate itemsets.
"""
function _replace_all_with_union!(
    P::Vector{Tuple{Vector{Int}, T}},
    xi::Vector{Int},
    x::Vector{Int},
) where {T}
    for k in eachindex(P)
        items_k, tid_k = P[k]
        all(in(Set(items_k)), xi) || continue
        P[k] = (union_items(items_k, x), tid_k)
    end
end

"""
    _insert_ordered!(Pi, x, y)

Inserts candidate `(x, y)` into `Pi` if absent, then keeps `Pi` ordered by itemset.

# Arguments
- `Pi::Vector{Tuple{Vector{Int}, T}}`: Candidate buffer.
- `x::Vector{Int}`: Candidate itemset.
- `y::T`: Candidate tidset.

# Returns
Mutates `Pi` and returns `nothing`.

# Complexity
`O(|Pi| log |Pi|)` due to duplicate scan plus full sort after insertion.
"""
function _insert_ordered!(
    Pi::Vector{Tuple{Vector{Int}, T}},
    x::Vector{Int},
    y::T,
) where {T}
    for (items, tid) in Pi
        items == x && tidset_equal(tid, y) && return
    end
    push!(Pi, (x, y))
    sort!(Pi; by = v -> v[1])
end

"""
    _add_closed_if_not_subsumed!(C, x, supx)

Adds closed itemset candidate `x` with support `supx` if it is not subsumed by existing closed itemsets.

# Arguments
- `C::Vector{FrequentItemset}`: Closed itemset accumulator.
- `x::Vector{Int}`: Candidate itemset.
- `supx::Int`: Candidate support.

# Returns
Mutates `C` and returns `nothing`.

# Complexity
`O(|C| * k)` where `k` is itemset containment-check cost.
"""
function _add_closed_if_not_subsumed!(
    C::Vector{FrequentItemset},
    x::Vector{Int},
    supx::Int,
)
    xset = Set(x)
    for fi in C
        if fi.support == supx && length(fi.items) > length(x)
            all(in(Set(fi.items)), x) && return
        end
    end
    filter!(fi -> !(fi.support == supx && length(fi.items) < length(x) && all(in(xset), fi.items)), C)
    push!(C, FrequentItemset(sort(unique(x)), supx))
end

"""
    _charm_extend!(P, C, min_sup)

Recursive CHARM extension step for mining closed frequent itemsets.

# Arguments
- `P::Vector{Tuple{Vector{Int}, T}}`: Current candidate equivalence class.
- `C::Vector{FrequentItemset}`: Output closed-itemset accumulator.
- `min_sup::Int`: Absolute minimum support threshold.

# Returns
Mutates `C` in-place and returns `nothing`.

# Complexity
Output-sensitive and data-dependent; worst case exponential in number of items.
"""
function _charm_extend!(
    P::Vector{Tuple{Vector{Int}, T}},
    C::Vector{FrequentItemset},
    min_sup::Int,
) where {T}
    i = 1
    while i <= length(P)
        xi, tid_i = P[i]
        Pi = Tuple{Vector{Int}, T}[]
        x = copy(xi)

        j = i + 1
        while j <= length(P)
            xj, tid_j = P[j]
            x_new = union_items(x, xj)
            y = intersect_tidset(tid_i, tid_j)

            if support(y) >= min_sup
                if tidset_equal(tid_i, tid_j) # Property 1
                    deleteat!(P, j)
                    _replace_all_with_union!(P, xi, x_new)
                    _replace_all_with_union!(Pi, xi, x_new)
                    x = x_new
                    xi = x
                    continue
                elseif tidset_proper_subset(tid_i, tid_j) # Property 2
                    _replace_all_with_union!(P, xi, x_new)
                    _replace_all_with_union!(Pi, xi, x_new)
                    x = x_new
                    xi = x
                elseif tidset_proper_superset(tid_i, tid_j) # Property 3
                    deleteat!(P, j)
                    _insert_ordered!(Pi, x_new, y)
                    continue
                else # Property 4
                    _insert_ordered!(Pi, x_new, y)
                end
            end
            j += 1
        end

        !isempty(Pi) && _charm_extend!(Pi, C, min_sup)
        _add_closed_if_not_subsumed!(C, x, support(tid_i))
        i += 1
    end
end

"""
    _mine_all_frequent!(out, prefix, candidates, min_sup, maxlen)

Depth-first enumeration of all frequent itemsets from candidate tidsets.

# Arguments
- `out::Vector{FrequentItemset}`: Output accumulator.
- `prefix::Vector{Int}`: Current prefix itemset.
- `candidates::Vector{Tuple{Int, T}}`: Candidate items with tidsets.
- `min_sup::Int`: Absolute minimum support threshold.
- `maxlen::Int`: Maximum allowed itemset length.

# Returns
Mutates `out` and returns `nothing`.

# Complexity
Output-sensitive; worst case exponential in number of frequent items.
"""
function _mine_all_frequent!(
    out::Vector{FrequentItemset},
    prefix::Vector{Int},
    candidates::Vector{Tuple{Int, T}},
    min_sup::Int,
    maxlen::Int,
) where {T}
    for i in eachindex(candidates)
        # Safe: i comes from eachindex(candidates).
        @inbounds item_i, tid_i = candidates[i]
        sup_i = support(tid_i)
        sup_i < min_sup && continue

        items_i = [prefix; item_i]
        push!(out, FrequentItemset(items_i, sup_i))
        length(items_i) >= maxlen && continue

        suffix = Tuple{Int, T}[]
        for j in (i + 1):length(candidates)
            # Safe: j iterates across valid candidate indices.
            @inbounds item_j, tid_j = candidates[j]
            tid_ij = intersect_tidset(tid_i, tid_j)
            support(tid_ij) >= min_sup && push!(suffix, (item_j, tid_ij))
        end

        !isempty(suffix) && _mine_all_frequent!(out, items_i, suffix, min_sup, maxlen)
    end
end

"""
    mine_frequent_itemsets(transactions, min_support; output_mode=:all, implementation=:bitset, max_itemset_length=typemax(Int)) -> MiningResult

Runs frequent itemset mining using either all-itemset DFS enumeration or CHARM closed-itemset search.

# Arguments
- `transactions::Vector{<:AbstractVector}`: Input transactions.
- `min_support::Real`: Minimum support (absolute or relative).
- `output_mode::Symbol=:all`: `:all` for all frequent itemsets, `:closed` for closed itemsets.
- `implementation::Symbol=:bitset`: `:basic` (set tidsets) or `:bitset` (bitvector tidsets).
- `max_itemset_length::Int=typemax(Int)`: Maximum output itemset length.

# Returns
- `MiningResult`: Mined itemsets and associated metadata.

# Complexity
Output-sensitive; worst case exponential in the number of frequent items.
"""
function mine_frequent_itemsets(transactions::Vector{<:AbstractVector}, min_support::Real;
                                output_mode::Symbol=:all,
                                implementation::Symbol=:bitset,
                                max_itemset_length::Int=typemax(Int))::MiningResult
    normalized = normalize_transactions(transactions)
    n = length(normalized)
    min_sup = resolve_min_support(min_support, n)

    vertical = if implementation == :bitset
        _build_vertical_bitset(normalized)
    elseif implementation == :basic
        _build_vertical_basic(normalized)
    else
        error("implementation must be :basic or :bitset")
    end

    T = implementation == :bitset ? BitVector : Set{Int}
    candidates = Tuple{Int, T}[]
    for item in sort(collect(keys(vertical)))
        tid = vertical[item]
        support(tid) >= min_sup && push!(candidates, (item, tid))
    end

    if output_mode == :all
        all_itemsets = FrequentItemset[]
        _mine_all_frequent!(all_itemsets, Int[], candidates, min_sup, max_itemset_length)

        unique_map = Dict{Tuple{Vararg{Int}}, Int}()
        for fi in all_itemsets
            unique_map[Tuple(fi.items)] = fi.support
        end
        deduped = [FrequentItemset(collect(k), v) for (k, v) in unique_map]
        sort!(deduped; by = x -> (length(x.items), x.items, x.support))
        return MiningResult(deduped, min_sup, n, output_mode, implementation)
    elseif output_mode == :closed
        P = [(Int[item], tid) for (item, tid) in candidates]
        C = FrequentItemset[]
        _charm_extend!(P, C, min_sup)

        unique_map = Dict{Tuple{Vararg{Int}}, Int}()
        for fi in C
            (length(fi.items) <= max_itemset_length) || continue
            unique_map[Tuple(sort(fi.items))] = fi.support
        end
        closed = [FrequentItemset(collect(k), v) for (k, v) in unique_map]
        sort!(closed; by = x -> (length(x.items), x.items, x.support))
        return MiningResult(closed, min_sup, n, output_mode, implementation)
    else
        error("output_mode must be :all or :closed")
    end
end

"""
    charm(transactions, min_support; kwargs...) -> MiningResult

Convenience alias for `mine_frequent_itemsets`.

# Arguments
- `transactions::Vector{<:AbstractVector}`: Input transactions.
- `min_support::Real`: Minimum support (absolute or relative).
- `kwargs...`: Forwarded keyword options accepted by `mine_frequent_itemsets`.

# Returns
- `MiningResult`: Mining result.

# Complexity
Same as `mine_frequent_itemsets`.
"""
charm(transactions::Vector{<:AbstractVector}, min_support::Real; kwargs...) =
    mine_frequent_itemsets(transactions, min_support; kwargs...)
