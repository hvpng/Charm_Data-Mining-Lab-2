include(joinpath(@__DIR__, "..", "structures.jl"))
include(joinpath(@__DIR__, "..", "utils.jl"))

using DataStructures: DefaultDict

support(t::Set{Int}) = length(t)
support(t::BitVector) = count(t)

intersect_tidset(a::Set{Int}, b::Set{Int}) = intersect(a, b)
intersect_tidset(a::BitVector, b::BitVector) = a .& b

tidset_equal(a::Set{Int}, b::Set{Int}) = a == b
tidset_equal(a::BitVector, b::BitVector) = a == b

tidset_subseteq(a::Set{Int}, b::Set{Int}) = issubset(a, b)
tidset_subseteq(a::BitVector, b::BitVector) = !any(a .& .!b)

tidset_proper_subset(a, b) = tidset_subseteq(a, b) && !tidset_equal(a, b)
tidset_proper_superset(a, b) = tidset_subseteq(b, a) && !tidset_equal(a, b)

union_items(a::Vector{Int}, b::Vector{Int}) = sort(unique(vcat(a, b)))

function _build_vertical_basic(transactions::Vector{Vector{Int}})
    tidsets = DefaultDict{Int, Set{Int}}(() -> Set{Int}())
    for (tid, txn) in enumerate(transactions)
        for item in txn
            push!(tidsets[item], tid)
        end
    end
    Dict(tidsets)
end

function _build_vertical_bitset(transactions::Vector{Vector{Int}})
    n = length(transactions)
    items = sort(unique(vcat(transactions...)))
    tidsets = Dict{Int, BitVector}(item => falses(n) for item in items)
    for (tid, txn) in enumerate(transactions)
        for item in txn
            tidsets[item][tid] = true
        end
    end
    tidsets
end

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

function _mine_all_frequent!(
    out::Vector{FrequentItemset},
    prefix::Vector{Int},
    candidates::Vector{Tuple{Int, T}},
    min_sup::Int,
    maxlen::Int,
) where {T}
    for i in eachindex(candidates)
        item_i, tid_i = candidates[i]
        sup_i = support(tid_i)
        sup_i < min_sup && continue

        items_i = [prefix; item_i]
        push!(out, FrequentItemset(items_i, sup_i))
        length(items_i) >= maxlen && continue

        suffix = Tuple{Int, T}[]
        for j in (i + 1):length(candidates)
            item_j, tid_j = candidates[j]
            tid_ij = intersect_tidset(tid_i, tid_j)
            support(tid_ij) >= min_sup && push!(suffix, (item_j, tid_ij))
        end

        !isempty(suffix) && _mine_all_frequent!(out, items_i, suffix, min_sup, maxlen)
    end
end

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

charm(transactions::Vector{<:AbstractVector}, min_support::Real; kwargs...) =
    mine_frequent_itemsets(transactions, min_support; kwargs...)
