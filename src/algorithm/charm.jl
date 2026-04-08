include(joinpath(@__DIR__, "..", "structures.jl"))
include(joinpath(@__DIR__, "..", "utils.jl"))

using DataStructures: DefaultDict

support(t::Set{Int}) = length(t)
support(t::BitVector) = count(t)

intersect_tidset(a::Set{Int}, b::Set{Int}) = intersect(a, b)
intersect_tidset(a::BitVector, b::BitVector) = a .& b

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

function _filter_closed(itemsets::Vector{FrequentItemset})
    keep = trues(length(itemsets))
    sorted = sort(itemsets; by = fi -> (fi.support, length(fi.items)))
    for i in eachindex(sorted)
        xi = sorted[i]
        for j in (i + 1):length(sorted)
            xj = sorted[j]
            xi.support == xj.support || continue
            xjset = Set(xj.items)
            if length(xj.items) > length(xi.items) && all(in(xjset), xi.items)
                keep[i] = false
                break
            end
        end
    end
    [sorted[i] for i in eachindex(sorted) if keep[i]]
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

    all_itemsets = FrequentItemset[]
    _mine_all_frequent!(all_itemsets, Int[], candidates, min_sup, max_itemset_length)

    unique_map = Dict{Tuple{Vararg{Int}}, Int}()
    for fi in all_itemsets
        unique_map[Tuple(fi.items)] = fi.support
    end
    deduped = [FrequentItemset(collect(k), v) for (k, v) in unique_map]
    sort!(deduped; by = x -> (length(x.items), x.items, x.support))

    final_itemsets = output_mode == :closed ? _filter_closed(deduped) : deduped
    MiningResult(final_itemsets, min_sup, n, output_mode, implementation)
end

charm(transactions::Vector{<:AbstractVector}, min_support::Real; kwargs...) =
    mine_frequent_itemsets(transactions, min_support; kwargs...)
