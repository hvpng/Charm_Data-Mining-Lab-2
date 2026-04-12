include(joinpath(@__DIR__, "..", "structures.jl"))
include(joinpath(@__DIR__, "..", "utils.jl"))

# ─────────────────────────────────────────────────────────────────────────────
# PHƯƠNG THỨC GENERIC CHO TIDSET (Dùng Multiple Dispatch để tối ưu)
# ─────────────────────────────────────────────────────────────────────────────

# Hỗ trợ BitVector (Tối ưu hóa bit-level)
@inline _support(t::BitVector) = count(t)
@inline _intersect_tidset(a::BitVector, b::BitVector) = a .& b
@inline _tidset_equal(a::BitVector, b::BitVector) = a == b

function _tidset_subseteq(a::BitVector, b::BitVector)::Bool
    c_a, c_b = a.chunks, b.chunks
    @inbounds for i in eachindex(c_a)
        (c_a[i] & ~c_b[i]) != 0 && return false
    end
    return true
end

# Hỗ trợ Set{Int} (Dành cho bản :basic so sánh)
@inline _support(t::Set{Int}) = length(t)
@inline _intersect_tidset(a::Set{Int}, b::Set{Int}) = intersect(a, b)
@inline _tidset_equal(a::Set{Int}, b::Set{Int}) = a == b
@inline _tidset_subseteq(a::Set{Int}, b::Set{Int}) = issubset(a, b)

# ─────────────────────────────────────────────────────────────────────────────
# HELPER FUNCTIONS (Sorted Itemsets)
# ─────────────────────────────────────────────────────────────────────────────

function _items_subseteq_sorted(a::Vector{Int}, b::Vector{Int})::Bool
    n_a, n_b = length(a), length(b)
    n_a > n_b && return false
    i = j = 1
    @inbounds while i <= n_a && j <= n_b
        if a[i] == b[j]
            i += 1; j += 1
        elseif a[i] > b[j]
            j += 1
        else
            return false
        end
    end
    return i > n_a
end

function _replace_prefix!(list, old_p::Vector{Int}, new_p::Vector{Int})
    @inbounds for k in eachindex(list)
        if _items_subseteq_sorted(old_p, list[k][1])
            list[k] = (sort!(union(list[k][1], new_p)), list[k][2])
        end
    end
end

function _is_subsumed(C_dict::Dict{Int, Vector{Vector{Int}}}, x::Vector{Int}, sup_x::Int)::Bool
    !haskey(C_dict, sup_x) && return false
    candidates = C_dict[sup_x]
    n_x = length(x)
    @inbounds for i in eachindex(candidates)
        target = candidates[i]
        if length(target) > n_x && _items_subseteq_sorted(x, target)
            return true
        end
    end
    return false
end

# ─────────────────────────────────────────────────────────────────────────────
# CHARM EXTEND (Generic Implementation)
# ─────────────────────────────────────────────────────────────────────────────

function _charm_extend!(
    P::Vector{Tuple{Vector{Int}, T}},
    C_dict::Dict{Int, Vector{Vector{Int}}},
    min_sup::Int
) where {T}
    i = 1
    while i <= length(P)
        xi, tid_xi = P[i]
        Pi = Tuple{Vector{Int}, T}[]
        X = copy(xi)
        
        j = i + 1
        while j <= length(P)
            xj, tid_xj = P[j]
            y_tid = _intersect_tidset(tid_xi, tid_xj)
            sup_y = _support(y_tid)

            if sup_y >= min_sup
                X_cand = sort!(union(xi, xj))
                
                if _tidset_equal(tid_xi, tid_xj)
                    # Property 1
                    old_xi = copy(xi)
                    X = X_cand
                    xi = X_cand
                    _replace_prefix!(P, old_xi, X)
                    _replace_prefix!(Pi, old_xi, X)
                    deleteat!(P, j)
                    continue
                elseif _tidset_subseteq(tid_xi, tid_xj)
                    # Property 2
                    old_xi = copy(xi)
                    X = X_cand
                    xi = X_cand
                    _replace_prefix!(P, old_xi, X)
                    _replace_prefix!(Pi, old_xi, X)
                elseif _tidset_subseteq(tid_xj, tid_xi)
                    # Property 3
                    deleteat!(P, j)
                    push!(Pi, (X_cand, y_tid))
                    continue
                else
                    # Property 4
                    push!(Pi, (X_cand, y_tid))
                end
            end
            j += 1
        end

        !isempty(Pi) && _charm_extend!(Pi, C_dict, min_sup)
        
        sup_X = _support(tid_xi)
        if !_is_subsumed(C_dict, X, sup_X)
            push!(get!(Vector{Vector{Int}}, C_dict, sup_X), X)
        end
        i += 1
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# PUBLIC API
# ─────────────────────────────────────────────────────────────────────────────

function charm(
    transactions::Vector{<:AbstractVector},
    min_support::Real;
    implementation::Symbol = :bitset
)::MiningResult
    normalized = normalize_transactions(transactions)
    n = length(normalized)
    abs_min_sup = resolve_min_support(min_support, n)
    items_list = sort!(unique!(reduce(vcat, normalized; init=Int[])))

    C_dict = Dict{Int, Vector{Vector{Int}}}()

    if implementation == :bitset
        # Cài đặt BitVector: Tiết kiệm bộ nhớ, AND cực nhanh
        db = Dict{Int, BitVector}(item => falses(n) for item in items_list)
        for (tid, txn) in enumerate(normalized)
            for item in txn
                @inbounds db[item][tid] = true
            end
        end
        
        P = Tuple{Vector{Int}, BitVector}[]
        for item in items_list
            tids = db[item]
            _support(tids) >= abs_min_sup && push!(P, ([item], tids))
        end
        _charm_extend!(P, C_dict, abs_min_sup)
    else
        # Cài đặt :basic (Set): Tốn bộ nhớ hơn (vượt test reduction)
        db_basic = Dict{Int, Set{Int}}()
        for (tid, txn) in enumerate(normalized)
            for item in txn
                push!(get!(Set{Int}, db_basic, item), tid)
            end
        end
        
        P_basic = Tuple{Vector{Int}, Set{Int}}[]
        for item in items_list
            if haskey(db_basic, item)
                tids = db_basic[item]
                _support(tids) >= abs_min_sup && push!(P_basic, ([item], tids))
            end
        end
        _charm_extend!(P_basic, C_dict, abs_min_sup)
    end

    # Thu thập kết quả
    final_itemsets = FrequentItemset[]
    for (sup, itemsets) in C_dict
        for items in itemsets
            push!(final_itemsets, FrequentItemset(items, sup))
        end
    end
    sort!(final_itemsets, by = x -> (length(x.items), x.items))

    return MiningResult(final_itemsets, abs_min_sup, n, :closed, implementation)
end