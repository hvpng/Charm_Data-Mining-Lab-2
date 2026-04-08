# charm.jl — CHARM algorithm using vertical (tidset) representation
#
# Reference: Zaki, M.J. & Hsiao, C.-J. (2002). CHARM: An Efficient Algorithm for
#            Closed Itemset Mining. Proceedings of the 2002 SIAM International
#            Conference on Data Mining, pp. 457–473.
#
# The algorithm mines all Frequent Closed Itemsets (FCIs) from a transaction
# database using a depth-first search over a set-enumeration tree.
# Tidsets allow O(1) support computation via set intersection.

include(joinpath(@__DIR__, "..", "structures.jl"))
include(joinpath(@__DIR__, "..", "utils.jl"))


# ─── Public API ──────────────────────────────────────────────────────────────

"""
    charm(transactions, min_support) -> CharmResult

Run the CHARM algorithm and return all frequent closed itemsets.

# Arguments
- `transactions`  — `Vector{Vector{String}}` (or any iterable of item lists)
- `min_support`   — minimum support, either
    * an `Int`   → absolute transaction count
    * a `Float64` in (0,1] → fraction of total transactions

# Returns
A `CharmResult` containing every frequent closed itemset with its support.

# Example
```julia
include("src/algorithm/charm.jl")
txns = [["a","b","c"],["a","b"],["b","c"]]
result = charm(txns, 2)
print_results(result)
```
"""
function charm(transactions::Vector{<:AbstractVector}, min_support::Real)::CharmResult
    n = length(transactions)
    min_sup = resolve_min_support(min_support, n)

    # Build per-item tidsets in a single database scan
    raw_tidsets = build_tidsets(transactions)

    # Keep only frequent single items; sort by increasing support (improves pruning)
    nodes = [ItemsetNode([item], tids)
             for (item, tids) in raw_tidsets
             if length(tids) >= min_sup]
    sort!(nodes; by=support)

    closed = Vector{ClosedItemset}()
    _charm_extend!(nodes, closed, min_sup)

    return CharmResult(closed, min_sup, n)
end


# ─── Internal helpers ────────────────────────────────────────────────────────

"""
    _charm_extend!(P, closed, min_sup)

Depth-first enumeration of the itemset lattice (CHARM-Extend procedure).

`P` is the current list of `ItemsetNode`s at this level of the search tree.
Discovered closed itemsets are appended to `closed`.
"""
function _charm_extend!(P::Vector{ItemsetNode},
                        closed::Vector{ClosedItemset},
                        min_sup::Int)
    n = length(P)
    removed = falses(n)          # marks nodes pruned from this level

    for i in 1:n
        removed[i] && continue

        # Local copies that may be extended by properties 2 and 4
        Xi  = copy(P[i].items)
        Ti  = P[i].tidset

        # Accumulate child nodes for the recursive call
        new_P = Vector{ItemsetNode}()

        for j in (i + 1):n
            removed[j] && continue

            Xj = P[j].items
            Tj = P[j].tidset

            # Tidset of the combined itemset Xi ∪ Xj
            T_new = intersect(Ti, Tj)
            length(T_new) < min_sup && continue   # below minimum support

            X_new = _merge_sorted(Xi, Xj)         # sorted union

            if Ti == Tj
                # ── Property 4: T(Xi) = T(Xj) ──────────────────────────────
                # Extend Xi with Xj's items; the combined node has the same
                # tidset, so Xj is fully subsumed — remove it from this level.
                Xi = X_new
                Ti = T_new
                removed[j] = true

            elseif issubset(Ti, Tj)
                # ── Property 2: T(Xi) ⊊ T(Xj) ──────────────────────────────
                # Every transaction that contains Xi also contains Xj, so Xi
                # and Xi ∪ Xj have the same tidset.  Extend Xi in place; Xj
                # stays for further pairing.
                Xi = X_new
                # Ti is unchanged (Ti ⊆ Tj  ⟹  Ti ∩ Tj = Ti)

            elseif issubset(Tj, Ti)
                # ── Property 3: T(Xj) ⊊ T(Xi) ──────────────────────────────
                # Xi ∪ Xj has Xj's tidset; Xj itself is subsumed — remove it.
                push!(new_P, ItemsetNode(X_new, T_new.tids))
                removed[j] = true

            else
                # ── Property 1: T(Xi) and T(Xj) are incomparable ────────────
                push!(new_P, ItemsetNode(X_new, T_new.tids))
            end
        end

        # Recurse on the children collected for Xi
        _charm_extend!(new_P, closed, min_sup)

        # Add Xi to closed itemsets if it is not already subsumed
        node_Xi = ItemsetNode(Xi, Ti.tids)
        if !_is_subsumed(node_Xi, closed)
            push!(closed, ClosedItemset(node_Xi))
        end
    end
end


"""
    _merge_sorted(a, b) -> Vector{String}

Return the sorted union of two already-sorted item vectors without duplicates.
"""
function _merge_sorted(a::Vector{String}, b::Vector{String})::Vector{String}
    result = Vector{String}(undef, length(a) + length(b))
    i, j, k = 1, 1, 1
    while i <= length(a) && j <= length(b)
        if a[i] < b[j]
            result[k] = a[i]; i += 1
        elseif a[i] > b[j]
            result[k] = b[j]; j += 1
        else
            result[k] = a[i]; i += 1; j += 1   # skip duplicate
        end
        k += 1
    end
    while i <= length(a); result[k] = a[i]; i += 1; k += 1; end
    while j <= length(b); result[k] = b[j]; j += 1; k += 1; end
    return result[1:k-1]
end


"""
    _is_subsumed(node, closed) -> Bool

Return `true` if `node` is already represented in `closed`, i.e. there
exists a closed itemset with the *same tidset* that is a superset of
`node.items`.  (Formally: node is not closed if a proper superset with
equal support already exists.)
"""
function _is_subsumed(node::ItemsetNode, closed::Vector{ClosedItemset})::Bool
    for ci in closed
        if ci.support == support(node) &&
           ci.tids == node.tidset.tids &&
           all(item -> item in ci.items, node.items)
            return true
        end
    end
    return false
end
