include(joinpath(@__DIR__, "..", "structures.jl"))
include(joinpath(@__DIR__, "..", "utils.jl"))

using DataStructures: DefaultDict

# ─────────────────────────────────────────────────────────────────────────────
# Tidset primitive operations
# ─────────────────────────────────────────────────────────────────────────────

support(t::Set{Int})   = length(t)
@inline support(t::BitVector) = @inbounds count(t)

intersect_tidset(a::Set{Int},  b::Set{Int})  = intersect(a, b)
function intersect_tidset(a::BitVector, b::BitVector)
    out = copy(a)
    out .&= b
    return out
end

tidset_equal(a::Set{Int},  b::Set{Int})  = a == b
tidset_equal(a::BitVector, b::BitVector) = a == b

tidset_subseteq(a::Set{Int},  b::Set{Int})  = issubset(a, b)
function tidset_subseteq(a::BitVector, b::BitVector)
    length(a) == length(b) || return false
    n_chunks = length(a.chunks)
    n_chunks == 0 && return true
    @inbounds for i in 1:(n_chunks - 1)
        (a.chunks[i] & ~b.chunks[i]) != 0 && return false
    end
    valid_bits = length(a) & 63
    last_mask = valid_bits == 0 ? typemax(UInt64) : (UInt64(1) << valid_bits) - UInt64(1)
    @inbounds begin
        a_last = a.chunks[n_chunks] & last_mask
        b_last = b.chunks[n_chunks] & last_mask
        (a_last & ~b_last) != 0 && return false
    end
    return true
end

"""
    union_items(a, b) -> Vector{Int}
Tính hợp của hai itemset đã sắp xếp, trả về sorted unique vector.
"""
union_items(a::Vector{Int}, b::Vector{Int}) = sort!(unique!(vcat(a, b)))

# ─────────────────────────────────────────────────────────────────────────────
# Vertical database construction
# ─────────────────────────────────────────────────────────────────────────────

function _build_vertical_basic(transactions::Vector{Vector{Int}})
    db = DefaultDict{Int, Set{Int}}(() -> Set{Int}())
    for (tid, txn) in enumerate(transactions)
        for item in txn
            push!(db[item], tid)
        end
    end
    Dict(db)
end

function _build_vertical_bitset(transactions::Vector{Vector{Int}})
    n     = length(transactions)
    items = sort!(unique!(reduce(vcat, transactions; init=Int[])))
    db    = Dict{Int, BitVector}(item => falses(n) for item in items)
    for (tid, txn) in enumerate(transactions)
        for item in txn
            @inbounds db[item][tid] = true
        end
    end
    db
end

# ─────────────────────────────────────────────────────────────────────────────
# CHARM Algorithm - Fresh Implementation from Zaki & Hsiao (2002) Paper
# ─────────────────────────────────────────────────────────────────────────────

"""
    _items_subseteq_sorted(a, b) -> Bool
Check if items array `a` ⊆ items array `b`, both sorted.
Two-pointer algorithm, O(|a| + |b|).
"""
function _items_subseteq_sorted(a::Vector{Int}, b::Vector{Int})::Bool
    i = j = 1
    @inbounds while i <= length(a) && j <= length(b)
        if a[i] == b[j]
            i += 1
            j += 1
        elseif a[i] > b[j]
            j += 1
        else
            return false
        end
    end
    return i > length(a)
end

"""
    _is_subsumed(C, x, sup_x) -> Bool
Check if itemset x is subsumed in C.
x is subsumed if ∃ Y ∈ C: Y ⊃ x ∧ σ(Y) = σ(x)
"""
function _is_subsumed(C::Vector{FrequentItemset}, x::Vector{Int}, sup_x::Int)::Bool
    for fi in C
        # Only check itemsets with same support
        fi.support != sup_x && continue
        # Only check longer itemsets (proper superset)
        length(fi.items) <= length(x) && continue
        # Check if x is subset of fi.items (both sorted)
        _items_subseteq_sorted(x, fi.items) && return true
    end
    return false
end

"""
    _charm_extend_v2!(P, C, min_sup)

Fresh implementation of CHARM-Extend following Zaki & Hsiao (2002) pseudocode exactly.

Paper pseudocode (Figure 5):
```
CHARM-EXTEND([P], C):
  4.  for each Xi × t(Xi) in [P]
  5.      [Pi] ← ∅ and X ← Xi
  6.      for each Xj × t(Xj) in [P], with Xj ≥f Xi
  7.          X ← X ∪ Xj and Y ← t(Xi) ∩ t(Xj)
  8.          CHARM-Property([P], [Pi])
  9.      if [Pi] ≠ ∅ then CHARM-Extend([Pi], C)
 10.      delete [Pi]
 11.     C ← C ∪ X  //if X is not subsumed
```

KEY INSIGHT: Line 7 computes X and Y based on ORIGINAL Xi and Xj from position i and j.
The while loop processes pairs (i,j) where j > i. When Properties 1-2 cause modifications
(replace Xi in place), those changes affect LATER iterations with larger j, because we're
modifying P while iterating through it.
"""
function _charm_extend_v2!(
    P::Vector{Tuple{Vector{Int}, T}},
    C::Vector{FrequentItemset},
    min_sup::Int,
) where {T}
    i = 1
    while i <= length(P)
        # Line 4: Extract Xi × t(Xi) - position i
        xi, tid_xi = P[i]

        # Line 5: Initialize Pi and X (and crucially, tid_X)
        Pi = Tuple{Vector{Int}, T}[]
        X = copy(xi)
        tid_X = copy(tid_xi)  # CRITICAL: Track tidset of accumulated X
        
        # Line 6: Inner loop over Xj with j > i  
        j = i + 1
        while j <= length(P)
            xj, tid_xj = P[j]

            # Line 7: Compute X ← X ∪ Xj and Y ← t(Xi) ∩ t(Xj)
            # CRITICAL: Use ORIGINAL xi and tid_xi (not accumulated X and tid_X)
            X_cand = union_items(X, xj)
            Y = intersect_tidset(tid_xi, tid_xj)

            # Line 8 (implicit): Only process if σ(Y) ≥ minsup
            if support(Y) >= min_sup
                # CHARM-Property logic
                if tidset_equal(tid_xi, tid_xj)
                    # PROPERTY 1: t(Xi) = t(Xj)
                    # Remove Xj; Replace all Xi with X_cand in [P]
                    xi_old = xi
                    deleteat!(P, j)
                    # Replace all occurrences of xi_old with X_cand in P[1..length(P)]
                    for k in eachindex(P)
                        if P[k][1] == xi_old
                            P[k] = (X_cand, P[k][2])
                        end
                    end
                    X = X_cand
                    xi = X_cand
                    tid_X = tid_xi  # t(Xi) = t(Xj) so tidset stays the same
                    # Don't increment j (deleted element)
                    continue

                elseif tidset_subseteq(tid_xi, tid_xj) && !tidset_equal(tid_xi, tid_xj)
                    # PROPERTY 2: t(Xi) ⊂ t(Xj)
                    # Replace all Xi with X_cand in [P] 
                    xi_old = xi
                    for k in eachindex(P)
                        if P[k][1] == xi_old
                            P[k] = (X_cand, P[k][2])
                        end
                    end
                    X = X_cand
                    xi = X_cand
                    tid_X = tid_xi  # t(X) = t(Xi) since t(Xi) ⊂ t(Xj)
                    j += 1

                elseif tidset_subseteq(tid_xj, tid_xi) && !tidset_equal(tid_xi, tid_xj)
                    # PROPERTY 3: t(Xi) ⊃ t(Xj)
                    # Remove Xj; Add X_cand × Y to [Pi]
                    deleteat!(P, j)
                    # Add to Pi if not already present
                    found = false
                    for (pi_items, pi_tid) in Pi
                        if pi_items == X_cand && tidset_equal(pi_tid, Y)
                            found = true
                            break
                        end
                    end
                    !found && push!(Pi, (X_cand, Y))
                    # Don't increment j (deleted)
                    continue

                else
                    # PROPERTY 4: t(Xi) and t(Xj) incomparable
                    # Add X_cand × Y to [Pi]
                    found = false
                    for (pi_items, pi_tid) in Pi
                        if pi_items == X_cand && tidset_equal(pi_tid, Y)
                            found = true
                            break
                        end
                    end
                    !found && push!(Pi, (X_cand, Y))
                    j += 1
                end
            else
                j += 1
            end
        end

        # Line 9: Recurse if [Pi] is non-empty
        if !isempty(Pi)
            _charm_extend_v2!(Pi, C, min_sup)
        end

        # Line 11: Add X to C if not subsumed
        sup_X = support(tid_X)  # Use the ACCUMULATED tidset from Properties
        X_sorted = sort!(unique!(X))
        if !_is_subsumed(C, X_sorted, sup_X)
            push!(C, FrequentItemset(X_sorted, sup_X))
        end

        i += 1
    end
end

"""
    charm(transactions, min_support; implementation=:bitset) -> MiningResult

New implementation of CHARM using fresh _charm_extend_v2!
"""
function charm(
    transactions::Vector{<:AbstractVector},
    min_support::Real;
    implementation::Symbol = :bitset,
)::MiningResult

    implementation in (:basic, :bitset) ||
        error("implementation phải là :basic hoặc :bitset")

    normalized = normalize_transactions(transactions)
    n = length(normalized)
    min_sup = resolve_min_support(min_support, n)

    # Build vertical database
    vertical = implementation == :bitset ?
        _build_vertical_bitset(normalized) :
        _build_vertical_basic(normalized)

    T = implementation == :bitset ? BitVector : Set{Int}

    # Line 1: P = {Xi × t(Xi) : Xi ∈ I ∧ σ(Xi) ≥ minsup}
    ordered_items = sort(collect(keys(vertical)))
    P = Tuple{Vector{Int}, T}[
        ([item], vertical[item])
        for item in ordered_items
        if support(vertical[item]) >= min_sup
    ]

    C = FrequentItemset[]

    # Line 2: CHARM-Extend([P], C)
    _charm_extend_v2!(P, C, min_sup)

    # Line 3: return C
    sort!(C; by = fi -> (length(fi.items), fi.items))
    return MiningResult(C, min_sup, n, :closed, implementation)
end
