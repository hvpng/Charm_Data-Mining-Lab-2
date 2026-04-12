include(joinpath(@__DIR__, "..", "structures.jl"))
include(joinpath(@__DIR__, "..", "utils.jl"))

using DataStructures: DefaultDict

# ─────────────────────────────────────────────────────────────────────────────
# GLOBAL DEBUG SWITCH
# ─────────────────────────────────────────────────────────────────────────────
const DEBUG_CHARM = true      # Đổi thành false để tắt hết debug
const MAX_DEBUG_LEVEL = 1   # Giới hạn độ sâu để tránh output quá lớn trên chess

function debug_print(level::Int, msg::String; color::Symbol = :white)
    if !DEBUG_CHARM
        return
    end
    colors = Dict(
        :yellow => "33", :green => "32", :cyan => "36",
        :magenta => "35", :blue => "34", :red => "31"
    )
    c = get(colors, color, "37")
    indent = "  "^level
    println("\033[1;$(c)m$(indent)[CHARM] $msg\033[0m")
end

function debug_tidset(tid; name="tidset", level=0)
    if !DEBUG_CHARM
        return
    end
    sup = support(tid)
    if tid isa BitVector
        ones = findall(tid)
        pos = length(ones) > 8 ? "$(ones[1:8])..." : ones
        debug_print(level, "$name: support=$sup | ones=$(length(ones)) | positions=$pos", color=:cyan)
    else
        debug_print(level, "$name: support=$sup | tids=$(collect(tid))", color=:cyan)
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# Tidset primitive operations (giữ nguyên + debug nhẹ)
# ─────────────────────────────────────────────────────────────────────────────
support(t::Set{Int}) = length(t)
@inline support(t::BitVector) = count(t)

intersect_tidset(a::Set{Int}, b::Set{Int}) = intersect(a, b)
function intersect_tidset(a::BitVector, b::BitVector)
    out = copy(a)
    out .&= b
    out
end

tidset_equal(a::Set{Int}, b::Set{Int}) = a == b
tidset_equal(a::BitVector, b::BitVector) = a == b

tidset_subseteq(a::Set{Int}, b::Set{Int}) = issubset(a, b)
function tidset_subseteq(a::BitVector, b::BitVector)
    length(a) == length(b) || return false
    n_chunks = length(a.chunks)
    n_chunks == 0 && return true

    @inbounds for i in 1:(n_chunks-1)
        (a.chunks[i] & ~b.chunks[i]) != 0 && return false
    end

    valid_bits = length(a) & 63
    last_mask = valid_bits == 0 ? typemax(UInt64) : (UInt64(1) << valid_bits) - UInt64(1)
    @inbounds begin
        a_last = a.chunks[n_chunks] & last_mask
        b_last = b.chunks[n_chunks] & last_mask
        (a_last & ~b_last) != 0 && return false
    end
    true
end

union_items(a::Vector{Int}, b::Vector{Int}) = sort!(unique!(vcat(a, b)))

# ─────────────────────────────────────────────────────────────────────────────
# DEBUG cho helper functions
# ─────────────────────────────────────────────────────────────────────────────
function _replace_Xi_with_X!(list::Vector{Tuple{Vector{Int}, T}}, xi_old::Vector{Int}, x_new::Vector{Int}) where {T}
    debug_print(2, "REPLACE: Replacing all Xi=$(xi_old) → $(x_new) in list of size $(length(list))", color=:magenta)
    count = 0
    for k in eachindex(list)
        if list[k][1] == xi_old
            list[k] = (copy(x_new), list[k][2])
            count += 1
        end
    end
    debug_print(2, "REPLACE done: replaced $count occurrences", color=:magenta)
end

function _insert_if_absent!(Pi::Vector{Tuple{Vector{Int}, T}}, x::Vector{Int}, y::T) where {T}
    for (items, tid) in Pi
        if items == x && tidset_equal(tid, y)
            debug_print(3, "INSERT skipped (already exists): $(x)", color=:yellow)
            return
        end
    end
    push!(Pi, (x, y))
    debug_print(3, "INSERTED into Pi: $(x) | sup=$(support(y))", color=:green)
end

function _items_subseteq_sorted(a::Vector{Int}, b::Vector{Int})::Bool
    i = j = 1
    @inbounds while i <= length(a) && j <= length(b)
        if a[i] == b[j]
            i += 1; j += 1
        elseif a[i] > b[j]
            j += 1
        else
            return false
        end
    end
    return i > length(a)
end

function _is_subsumed(C::Vector{FrequentItemset}, x::Vector{Int}, sup_x::Int)::Bool
    debug_print(2, "SUBSUMED CHECK for $(x) | sup=$sup_x against $(length(C))", color=:yellow)
    # Ưu tiên check itemset dài hơn trước
    sorted_C = sort(C; by = fi -> -length(fi.items))
    for fi in sorted_C
        if fi.support == sup_x && length(fi.items) > length(x)
            if _items_subseteq_sorted(x, fi.items)
                debug_print(2, "→ SUBSUMED by $(fi.items)", color=:red)
                return true
            end
        end
    end
    debug_print(2, "→ NOT subsumed", color=:green)
    return false
end

# ─────────────────────────────────────────────────────────────────────────────
# Build vertical database với debug
# ─────────────────────────────────────────────────────────────────────────────
function _build_vertical_basic(transactions::Vector{Vector{Int}})
    debug_print(0, "Building vertical DB (Set{Int}) ...", color=:blue)
    db = DefaultDict{Int, Set{Int}}(() -> Set{Int}())
    for (tid, txn) in enumerate(transactions)
        for item in txn
            push!(db[item], tid)
        end
    end
    debug_print(0, "Vertical DB built: $(length(db)) items", color=:blue)
    Dict(db)
end

function _build_vertical_bitset(transactions::Vector{Vector{Int}})
    debug_print(0, "Building vertical DB (BitVector) ... n_transactions=$(length(transactions))", color=:blue)
    n = length(transactions)
    items = sort!(unique!(reduce(vcat, transactions; init=Int[])))
    db = Dict{Int, BitVector}(item => falses(n) for item in items)

    for (tid, txn) in enumerate(transactions)
        for item in txn
            @inbounds db[item][tid] = true
        end
    end
    debug_print(0, "BitVector vertical DB built: $(length(db)) items", color=:blue)
    db
end

# ─────────────────────────────────────────────────────────────────────────────
# CHARM EXTEND - PHIÊN BẢN DEBUG CHI TIẾT CHO CHESS/MUSHROOM
# ─────────────────────────────────────────────────────────────────────────────
function _charm_extend!(
    P::Vector{Tuple{Vector{Int}, T}},
    C::Vector{FrequentItemset},
    min_sup::Int,
    level::Int = 0
) where {T}

    debug_print(level, "ENTER level=$level | P size=$(length(P))", color=:yellow)

    i = 1
    while i <= length(P)
        xi, tid_xi = P[i]
        debug_print(level+1, "i=$i | Xi=$(xi) | sup=$(support(tid_xi))", color=:green)

        Pi    = Tuple{Vector{Int}, T}[]
        X     = copy(xi)          # itemset đang tích lũy
        tid_X = tid_xi            # tidset tương ứng với X hiện tại

        j = i + 1
        while j <= length(P)
            xj, tid_xj = P[j]

            X_cand = union_items(X, xj)
            Y      = intersect_tidset(tid_xi, tid_xj)   # luôn giao với tid_xi gốc
            sup_Y  = support(Y)

            if sup_Y >= min_sup
                if tidset_equal(tid_xi, tid_xj)
                    # PROPERTY 1
                    debug_print(level+2, "→ PROPERTY 1: t(Xi)==t(Xj) | replace Xi → $(X_cand)", color=:magenta)
                    xi_old = xi
                    deleteat!(P, j)
                    _replace_Xi_with_X!(P,  xi_old, X_cand)
                    _replace_Xi_with_X!(Pi, xi_old, X_cand)
                    X     = X_cand
                    xi    = X_cand
                    tid_X = tid_xi          # tidset không đổi
                    continue   # không tăng j vì đã xóa

                elseif tidset_subseteq(tid_xi, tid_xj) && !tidset_equal(tid_xi, tid_xj)
                    # PROPERTY 2
                    debug_print(level+2, "→ PROPERTY 2: t(Xi) ⊂ t(Xj) | replace Xi → $(X_cand)", color=:magenta)
                    xi_old = xi
                    _replace_Xi_with_X!(P,  xi_old, X_cand)
                    _replace_Xi_with_X!(Pi, xi_old, X_cand)
                    X     = X_cand
                    xi    = X_cand
                    tid_X = tid_xi          # tidset vẫn của Xi
                    j += 1

                elseif tidset_subseteq(tid_xj, tid_xi) && !tidset_equal(tid_xi, tid_xj)
                    # PROPERTY 3
                    debug_print(level+2, "→ PROPERTY 3: t(Xi) ⊃ t(Xj)", color=:magenta)
                    deleteat!(P, j)
                    _insert_if_absent!(Pi, X_cand, Y)

                else
                    # PROPERTY 4
                    debug_print(level+2, "→ PROPERTY 4: incomparable", color=:magenta)
                    _insert_if_absent!(Pi, X_cand, Y)
                    j += 1
                end
            else
                j += 1
            end
        end

        # Recurse vào Pi
        if !isempty(Pi)
            debug_print(level+1, "Recurse into Pi (size=$(length(Pi)))", color=:blue)
            _charm_extend!(Pi, C, min_sup, level + 1)
        end

        # Add vào C (đảm bảo sorted và unique)
        sup_X = support(tid_X)
        sorted_X = sort!(unique!(X))
        debug_print(level+1, "Candidate to C: $(sorted_X) | sup=$sup_X", color=:yellow)

        if !_is_subsumed(C, sorted_X, sup_X)
            debug_print(level+1, "→ ADDED to C: $(sorted_X) (sup=$sup_X)", color=:green)
            push!(C, FrequentItemset(sorted_X, sup_X))
        else
            debug_print(level+1, "→ SKIPPED (subsumed): $(sorted_X)", color=:red)
        end

        i += 1
    end

    debug_print(level, "EXIT level=$level", color=:yellow)
end

# ─────────────────────────────────────────────────────────────────────────────
# Public API với debug
# ─────────────────────────────────────────────────────────────────────────────
function charm(
    transactions::Vector{<:AbstractVector},
    min_support::Real;
    implementation::Symbol = :bitset
)::MiningResult

    debug_print(0, "=== CHARM START ===", color=:blue)
    debug_print(0, "transactions: $(length(transactions)) | min_support=$min_support | impl=$implementation", color=:blue)

    implementation in (:basic, :bitset) || error("implementation phải là :basic hoặc :bitset")

    normalized = normalize_transactions(transactions)
    n          = length(normalized)
    min_sup    = resolve_min_support(min_support, n)

    debug_print(0, "Normalized: $n transactions | resolved min_sup = $min_sup", color=:blue)

    vertical = implementation == :bitset ?
        _build_vertical_bitset(normalized) :
        _build_vertical_basic(normalized)

    T = implementation == :bitset ? BitVector : Set{Int}

    ordered_items = sort(collect(keys(vertical)))
    P = Tuple{Vector{Int}, T}[
        ([item], vertical[item])
        for item in ordered_items
        if support(vertical[item]) >= min_sup
    ]

    debug_print(0, "Initial P built: $(length(P)) single-item frequent itemsets", color=:blue)

    C = FrequentItemset[]

    debug_print(0, "Starting CHARM-Extend on root P ...", color=:blue)
    _charm_extend!(P, C, min_sup, 0)

    # ─────────────────────────────────────────────────────────────
    # POST-PROCESSING: Loại bỏ tất cả non-closed itemsets (theo định nghĩa closed)
    # Đây là bước cần thiết để khớp SPMF/reference khi dùng DFS
    # ─────────────────────────────────────────────────────────────
    debug_print(0, "Post-processing: Removing non-closed itemsets from $(length(C)) candidates...", color=:blue)

    # Group theo support để nhanh
    by_sup = Dict{Int, Vector{FrequentItemset}}()
    for fi in C
        push!(get!(Vector{FrequentItemset}, by_sup, fi.support), fi)
    end

    final_C = FrequentItemset[]
    for sup in sort(collect(keys(by_sup)))  # support nhỏ đến lớn cũng được
        candidates = by_sup[sup]
        for fi in candidates
            is_subsumed = false
            for other in final_C
                if other.support == sup && length(other.items) > length(fi.items)
                    if _items_subseteq_sorted(fi.items, other.items)
                        is_subsumed = true
                        debug_print(1, "Post-remove subsumed: $(fi.items) by $(other.items)", color=:red)
                        break
                    end
                end
            end
            if !is_subsumed
                push!(final_C, fi)
            end
        end
    end

    C = final_C
    # ─────────────────────────────────────────────────────────────

    sort!(C; by = fi -> (length(fi.items), fi.items))

    debug_print(0, "=== CHARM FINISHED === Found $(length(C)) closed itemsets (after post-processing)", color=:green)

    return MiningResult(C, min_sup, n, :closed, implementation)
end